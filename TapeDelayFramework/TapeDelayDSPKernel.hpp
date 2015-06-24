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
    DelayParamDelayTime,
    DelayParamDelayLevel,
    DelayParamFeedback,
    DelayParamTape
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
        bufferSize = sampleRate * (maxDelayTimeMS / 1000.0); // Max 2 seconds delay
        
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
            
            double delayTime = double(delayTimeRamper.getStep());
            double feedback = double(feedbackRamper.getStep());
            double mix = double(delayLevelRamper.getStep());
            double tape = double(tapeRamper.getStep());
            
            for (int channel = 0; channel < channelCount; ++channel) {
                DelayState &state = delayStates[channel];
                
                float *in   = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                float *out  = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                
                float delayOffset = (delayTime / 1000) * sampleRate;
                SInt32 delayLocation = state.bufferPosition - floor(delayOffset);
                while (delayLocation < 0) {
                    delayLocation += bufferSize;
                }
                
                float delayMix = state.tapeBuffer[delayLocation] + *in;
                if (delayMix > 1.0) {
                    delayMix = 1.0;
                } else if (delayMix < -1.0) {
                    delayMix = -1.0;
                }
                
                *out = *in + (delayMix - *in) * mix;
                
                float feedbackSignal = *in + (delayMix * feedback);
                feedback = tanhf((feedbackSignal / 2.0) * ((tape * 10) + 2));
                if (feedbackSignal > 1.0) {
                    feedbackSignal = 1.0;
                } else if (feedbackSignal < -1.0) {
                    feedbackSignal = -1.0;
                }
                
                state.bufferPosition++;
                while (state.bufferPosition > bufferSize) {
                    state.bufferPosition -= bufferSize;
                }
                state.tapeBuffer[state.bufferPosition] = feedbackSignal;
            }
            
            }
        }

    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case DelayParamDelayTime:
                delayTimeRamper.set(clamp(value, 100.0f, 2000.0f));
                break;
            case DelayParamDelayLevel:
                delayLevelRamper.set(clamp(value, 0.0f, 1.0f));
                break;
            case DelayParamFeedback:
                feedbackRamper.set(clamp(value, 0.0f, 1.0f));
                break;
            case DelayParamTape:
                tapeRamper.set(clamp(value, 0.0f, 1.0f));
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case DelayParamDelayTime:
                return delayTimeRamper.goal();
            case DelayParamDelayLevel:
                return delayLevelRamper.goal();
            case DelayParamFeedback:
                return feedbackRamper.goal();
            case DelayParamTape:
                return tapeRamper.goal();
            default: return 0.0f;
        }
    }
    
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        switch (address) {
            case DelayParamDelayTime:
                delayTimeRamper.startRamp(clamp(value, 100.0f, 2000.0f), duration);
                break;
            case DelayParamDelayLevel:
                delayLevelRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
                break;
            case DelayParamFeedback:
                feedbackRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
                break;
            case DelayParamTape:
                tapeRamper.startRamp(clamp(value, 0.0f, 1.0f), duration);
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
    ParameterRamper delayTimeRamper     = 500.0;
    ParameterRamper delayLevelRamper    = 0.0;
    ParameterRamper feedbackRamper      = 0.0;
    ParameterRamper tapeRamper          = 0.0;
    
};


#endif /* TapeDelayDSPKernel_cpp */
