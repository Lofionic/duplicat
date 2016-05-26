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
        
        float f, p, q;
        float b0, b1, b2, b3, b4;
        float t1, t2;
        
        void init(UInt32 bufferSize) {
            free(tapeBuffer);
            tapeBuffer = (float*)malloc(bufferSize * sizeof(float));
            memset(tapeBuffer, 0, bufferSize * sizeof(float));
            
            bufferPosition = 0;
            
            f = p = q = b0 = b1 = b2 = b3 = b4 = t1 = t2 = 0;
        }
    };
    
    TapeDelayDSPKernel() {}
    
    void init(int channelCount, double inSampleRate) {
        delayStates.resize(channelCount);
        
        sampleRate = float(inSampleRate);
        bufferSize = sampleRate * 10 * (maxDelayTimeMS / 1000.0);
        
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
        
        float delaySignal = 0;
        
        if (shortDelay == true) {
            float shortDelayOffset = 6 * sampleRate; // 600ms+

            SInt32 shortDelayLocationH = state.bufferPosition - ceil(shortDelayOffset);
            while (shortDelayLocationH < 0) {
                shortDelayLocationH += bufferSize;
            }
            
            SInt32 shortDelayLocationL = state.bufferPosition - floor(shortDelayOffset);
            
            while (shortDelayLocationL < 0) {
                shortDelayLocationL = bufferSize + shortDelayLocationL;
            }
            
            float d = shortDelayOffset - floor(shortDelayOffset);
            float s = (state.tapeBuffer[shortDelayLocationL] + (state.tapeBuffer[shortDelayLocationH] - state.tapeBuffer[shortDelayLocationL]) * d);

            delaySignal = s;
        }
        
        if (mediumDelay) {
            float medDelayOffset = 12 * sampleRate; // 1200ms+
            SInt32 medDelayLocationH = state.bufferPosition - ceil(medDelayOffset);
            while (medDelayLocationH < 0) {
                medDelayLocationH += bufferSize;
            }
            
            SInt32 medDelayLocationL = state.bufferPosition - floor(medDelayOffset);
            
            while (medDelayLocationL < 0) {
                medDelayLocationL = bufferSize + medDelayLocationL;
            }
            
            float d = medDelayOffset - floor(medDelayOffset);
            float s = (state.tapeBuffer[medDelayLocationL] + (state.tapeBuffer[medDelayLocationH] - state.tapeBuffer[medDelayLocationL]) * d);
            
            delaySignal = tanhf(delaySignal + s);
        }
        
        if (longDelay) {
            float longDelayOffset = 20 * sampleRate; // 2000ms+
            SInt32 delayLocationH = state.bufferPosition - ceil(longDelayOffset);
            while (delayLocationH < 0) {
                delayLocationH += bufferSize;
            }
            
            SInt32 delayLocationL = state.bufferPosition - floor(longDelayOffset);
            while (delayLocationL < 0) {
                delayLocationL += bufferSize;
            }
            
            float d = longDelayOffset - floor(longDelayOffset);
            float s = (state.tapeBuffer[delayLocationL] + (state.tapeBuffer[delayLocationH] - state.tapeBuffer[delayLocationL]) * d);
            
            s = state.tapeBuffer[delayLocationH];
            
            delaySignal = tanhf(delaySignal + s);
        }

        float feedbackSignal = tanhf(*in + (delaySignal * feedback * 2));
        
        // Apply tape distortion to recorded signal
        float distortion = tanhf(feedbackSignal * 10) / 5;
        feedbackSignal = feedbackSignal + ((distortion - feedbackSignal) * tapeEffect);
        
        // Filter feedback signal
        float cutoff = 0.7 - (tapeEffect * 0.5);
        state.q = 1.0f - cutoff;
        state.p = cutoff + 0.8f * cutoff * state.q;
        state.f = state.p + state.p - 1.0f;
        
        state.q = 0 * (1.0f + 0.5f * state.q * (1.0f - state.q + 5.6f * state.q * state.q));
        
        feedbackSignal -= state.q * state.b4; //feedback
        
        state.t1 = state.b1;  state.b1 = (feedbackSignal + state.b0) * state.p - state.b1 * state.f;
        state.t2 = state.b2;  state.b2 = (state.b1 + state.t1) * state.p - state.b2 * state.f;
        state.t1 = state.b3;  state.b3 = (state.b2 + state.t2) * state.p - state.b3 * state.f;
        state.b4 = (state.b3 + state.t1) * state.p - state.b4 * state.f;

        state.b4 = state.b4 - state.b4 * state.b4 * state.b4 * 0.166667f;    //clipping
        
        feedbackSignal = state.b4;
        
        *out = *in + ((delaySignal - *in) * mix);
        
        // Writes to the tape buffer.
        UInt32 n = 10 + (50.0 * tapeSpeed);

        float rampFrom = lastSample;
        for (int j = 0; j < n; j++) {
            float d = (float)j / n;
            lastSample = rampFrom + ((feedbackSignal - rampFrom) * d);
            state.tapeBuffer[state.bufferPosition] = lastSample;
            state.bufferPosition++;
            while (state.bufferPosition >= bufferSize) {
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
    
    float lastSample;
    
    AudioBufferList* inBufferListPtr = nullptr;
    AudioBufferList* outBufferListPtr = nullptr;
    
public:
    ParameterRamper tapeSpeedRamper = 0.0;
    ParameterRamper mixRamper = 0.0;
    ParameterRamper feedbackRamper = 0.0;
    ParameterRamper tapeEffectRamper = 0.0;
    
    bool shortDelay;
    bool mediumDelay;
    bool longDelay;
};


#endif /* TapeDelayDSPKernel_cpp */
