//
//  TapeDelayDSPKernel.hpp
//  TapeDelay
//
//  Created by Chris on 20/06/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//

#ifndef TapeDelayDSPKernel_cpp
#define TapeDelayDSPKernel_cpp

#import "DSPKernel.hpp"
#import "ParameterRamper.hpp"
#import <vector>

enum {
    DelayParamTapeSpeed,
    DelayParamMix,
    DelayParamFeedback,
    DelayParamTapeEffect,
    DelayParamShortDelay,
    DelayParamMediumDelay,
    DelayParamLongDelay
};

class TapeDelayDSPKernel : public DSPKernel {
    
public:
    // MARK: Types
    struct DelayState {
        float *tapeBuffer;
        UInt32 bufferPosition = 0;
        
        void init(UInt32 bufferSize) {
            free(tapeBuffer);
            tapeBuffer = (float*)malloc(bufferSize * sizeof(float));
            memset(tapeBuffer, 0, bufferSize * sizeof(float));
            
            bufferPosition = 0;
        }
    };
    
    TapeDelayDSPKernel() {}
    
    void init(int channelCount, double inSampleRate) {
        delayStates.resize(channelCount);
        
        sampleRate = float(inSampleRate);
        bufferSize = sampleRate * (maxDelayTimeMS / 1000.0);
        
        for (DelayState& state : delayStates) {
            state.init(bufferSize);
        }
    }
    
    void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {
        inBufferListPtr = inBufferList;
        outBufferListPtr = outBufferList;
    }

    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        int channelCount = int(delayStates.size());
        
        // For each sample.
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            int frameOffset = int(frameIndex + bufferOffset);
            
            double tapeSpeed = double(tapeSpeedRamper.getStep());
            double feedback = double(feedbackRamper.getStep());
            double mix = double(mixRamper.getStep());
            double tapeEffect = double(tapeEffectRamper.getStep());
            
            for (int channel = 0; channel < channelCount; ++channel) {
                DelayState &state = delayStates[channel];
                
                float *in   = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                float *out  = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                
                applyDelay(state, in, out, tapeSpeed, feedback, mix, tapeEffect);
            }
        }
    }
    
    void applyDelay(DelayState &state, float *in, float *out, double tapeSpeed, double feedback, double mix, double tapeEffect) {
        
        float delayMix = 0;
        
        if (shortDelay == true) {
            float shortDelayOffset = (100 / 1000.) * sampleRate; // 300ms
            SInt32 shortDelayLocation = state.bufferPosition - floor(shortDelayOffset);
            while (shortDelayLocation < 0) {
                shortDelayLocation += bufferSize;
            }
            
            delayMix += state.tapeBuffer[shortDelayLocation];
        }
        
        if (mediumDelay) {
            float mediumDelayOffset = (400 / 1000.) * sampleRate; // 600ms
            SInt32 mediumDelayLocation = state.bufferPosition - floor(mediumDelayOffset);
            while (mediumDelayLocation < 0) {
                mediumDelayLocation += bufferSize;
            }
            
            delayMix += state.tapeBuffer[mediumDelayLocation];
        }
        
        if (longDelay) {
            float longDelayOffset = (900 / 1000.) * sampleRate; // 900ms
            SInt32 longDelayLocation = state.bufferPosition - floor(longDelayOffset);
            while (longDelayLocation < 0) {
                longDelayLocation += bufferSize;
            }
            
            delayMix += state.tapeBuffer[longDelayLocation];
        }
        
        if (delayMix > 1.0) {
            delayMix = 1.0;
        } else if (delayMix < -1.0) {
            delayMix = -1.0;
        }
        
        *out = *in + ((delayMix - *in) * mix);
        
        float feedbackSignal =  *in + (delayMix * feedback);
        
        // Apply tape distortion to recorded signal
        float signalClip = 1 - (tapeEffect * 0.9);
        
        //float distortedSignal = tanhf(feedbackSignal * 2.0);
        //feedbackSignal = feedbackSignal + ((distortedSignal - feedbackSignal) * tapeEffect);
        
        if (feedbackSignal > signalClip) {
            feedbackSignal = signalClip;
        } else if (feedbackSignal < -signalClip) {
            feedbackSignal = -signalClip;
        }
        
        UInt32 n = 1 + (10.0 * tapeSpeed);
        for (int j = 0; j < n; j++) {
            state.tapeBuffer[state.bufferPosition] = feedbackSignal;
            state.bufferPosition++;
            while (state.bufferPosition > bufferSize) {
                state.bufferPosition -= bufferSize;
            }
        }
    }

    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case DelayParamTapeSpeed:
                tapeSpeedRamper.set(clamp(value, 0.0f, 1.0f));
                break;
            case DelayParamMix:
                mixRamper.set(clamp(value, 0.0f, 1.0f));
                break;
            case DelayParamFeedback:
                feedbackRamper.set(clamp(value, 0.0f, 1.0f));
                break;
            case DelayParamTapeEffect:
                tapeEffectRamper.set(clamp(value, 0.0f, 1.0f));
                break;
            case DelayParamShortDelay:
                shortDelay = (value > 0);
                break;
            case DelayParamMediumDelay:
                mediumDelay = (value > 0);
                break;
            case DelayParamLongDelay:
                longDelay = (value > 0);
                break;
                
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case DelayParamTapeSpeed:
                return tapeSpeedRamper.goal();
            case DelayParamMix:
                return mixRamper.goal();
            case DelayParamFeedback:
                return feedbackRamper.goal();
            case DelayParamTapeEffect:
                return tapeEffectRamper.goal();
            case DelayParamShortDelay:
                return shortDelay;
            case DelayParamMediumDelay:
                return mediumDelay;
            case DelayParamLongDelay:
                return longDelay;
            default: return 0.0f;
        }
    }
    
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        switch (address) {
            case DelayParamTapeSpeed:
                tapeSpeedRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
                break;
            case DelayParamMix:
                mixRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
                break;
            case DelayParamFeedback:
                feedbackRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
                break;
            case DelayParamTapeEffect:
                tapeEffectRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
                break;
            case DelayParamShortDelay:
                shortDelay = (value > 0);
                break;
            case DelayParamMediumDelay:
                mediumDelay = (value > 0);
                break;
            case DelayParamLongDelay:
                longDelay = (value > 0);
        }
    }
    
    void reset() {
        for (DelayState& state : delayStates) {
            state.init(bufferSize);
        }
    }
    
    
private:
   
    std::vector<DelayState> delayStates;
    
    float sampleRate = 44100.0;
    float maxDelayTimeMS = 2000;
    UInt32 bufferSize;
    
    AudioBufferList* inBufferListPtr = nullptr;
    AudioBufferList* outBufferListPtr = nullptr;
    
public:
    ParameterRamper tapeSpeedRamper     = 1.0;
    ParameterRamper mixRamper           = 0.0;
    ParameterRamper feedbackRamper      = 0.0;
    ParameterRamper tapeEffectRamper    = 0.0;
    
    bool shortDelay;
    bool mediumDelay;
    bool longDelay;
};


#endif /* TapeDelayDSPKernel_cpp */
