//
//  TapeDelay.m
//  TapeDelay
//
//  Created by Chris on 16/06/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//

#import "TapeDelay.h"
#import <AVFoundation/AVFoundation.h>
#import "TapeDelayDSPKernel.hpp"
#import "BufferedAudioBus.hpp"

@interface TapeDelay ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation TapeDelay {
    TapeDelayDSPKernel _kernel;
    BufferedInputBus _inputBus;
}
@synthesize parameterTree = _parameterTree;

-(instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError * __nullable __autoreleasing * __nullable)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    // Initialize default format for the busses
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];
    
    // Create a DSP kernel to handle the signal processing
    _kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    
    // Create parameter objects
    AUParameter *delayTime = [AUParameterTree createParameterWithIdentifier:@"delayTime" name:@"Delay Time"
                                                                    address:DelayParamDelayTime
                                                                        min:100.0
                                                                        max:2000.0
                                                                       unit:kAudioUnitParameterUnit_Milliseconds
                                                                   unitName:nil
                                                                      flags:0
                                                               valueStrings:nil
                                                        dependentParameters:nil];
    
    AUParameter *delayLevel = [AUParameterTree createParameterWithIdentifier:@"delayLaevel" name:@"Delay Level"
                                                                     address:DelayParamDelayLevel
                                                                         min:0
                                                                         max:1.0
                                                                        unit:kAudioUnitParameterUnit_LinearGain
                                                                    unitName:nil
                                                                       flags:0
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    AUParameter *feedback = [AUParameterTree createParameterWithIdentifier:@"feedback" name:@"Feedback"
                                                                     address:DelayParamFeedback
                                                                         min:0
                                                                         max:1.0
                                                                        unit:kAudioUnitParameterUnit_LinearGain
                                                                    unitName:nil
                                                                       flags:0
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    
    // Initialize parameter values
    delayTime.value =   500;
    delayLevel.value =  0.5;
    feedback.value =    0.2;
    _kernel.setParameter(DelayParamDelayTime, delayTime.value);
    _kernel.setParameter(DelayParamDelayLevel, delayLevel.value);
    _kernel.setParameter(DelayParamFeedback, feedback.value);
    
    // Create the parameter tree
    _parameterTree = [AUParameterTree createTreeWithChildren:@[
                                                               delayTime,
                                                               delayLevel,
                                                               feedback
                                                               ]];
    
    // Create the input and output busses.
    _inputBus.init(defaultFormat, 8);
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    
    // Create the input and output bus arrays
    _inputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[_inputBus.bus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_outputBus]];
    
    // Make a local pointer to the kernel to avoid capturing self
    __block TapeDelayDSPKernel *delayKernel = &_kernel;
    
    // implementorValueObserver is called when a parameter changes value.
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        delayKernel->setParameter(param.address, value);
    };
    
    // implementorValueProvider is called when the value needs to be refreshed.
    _parameterTree.implementorValueProvider = ^(AUParameter *param) {
        return delayKernel->getParameter(param.address);
    };
    
    // A function to provide string representations of parameter values
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        switch (param.address) {
            case DelayParamDelayTime:
                return [NSString stringWithFormat:@"%.0fms", value];
                
            case DelayParamDelayLevel:
                return [NSString stringWithFormat:@"%.2f", value];
                
            case DelayParamFeedback:
                return [NSString stringWithFormat:@"%.2f", value];
            default:
                return @"?";
            }
    };
    
    self.maximumFramesToRender = 512;
    return self;
}


#pragma mark - AVAudioUnit overrides

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

-(BOOL)allocateRenderResourcesAndReturnError:(NSError * __nullable __autoreleasing * __nullable)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        
        return NO;
    }
    
    _inputBus.allocateRenderResources(self.maximumFramesToRender);
    
    _kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
    _kernel.reset();
    
    /*
     While rendering, we want to schedule all parameter changes. Setting them
     off the render thread is not thread safe.
     */
    __block AUScheduleParameterBlock scheduleParameter = self.scheduleParameterBlock;
    
    // Ramp over 20 milliseconds.
    __block AUAudioFrameCount rampTime = AUAudioFrameCount(0.02 * self.outputBus.format.sampleRate);
    
    self.parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        scheduleParameter(AUEventSampleTimeImmediate, rampTime, param.address, value);
    };
    
    return YES;
}

-(void)deallocateRenderResources {
    [super deallocateRenderResources];
    
    _inputBus.deallocateRenderResources();
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block TapeDelayDSPKernel *delayKernel = &_kernel;
    
    // Go back to setting parameters instead of scheduling them.
    self.parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        delayKernel->setParameter(param.address, value);
    };
}

-(AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    __block TapeDelayDSPKernel *state = &_kernel;
    __block BufferedInputBus *input = &_inputBus;
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        AudioUnitRenderActionFlags pullFlags = 0;
        
        AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
        
        if (err != 0) {
            return err;
        }
        
        AudioBufferList *inAudioBufferList = input->mutableAudioBufferList;
        
        /*
         If the caller passed non-nil output pointers, use those. Otherwise,
         process in-place in the input buffer. If your algorithm cannot process
         in-place, then you will need to preallocate an output buffer and use
         it here.
         */
        AudioBufferList *outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i <= outAudioBufferList->mNumberBuffers; ++i) {
                outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }
        
        state->setBuffers(inAudioBufferList, outAudioBufferList);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };
}

@end