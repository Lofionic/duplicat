//
//  IAAWrapper.swift
//  Duplicat
//
//  Created by Chris Rivers on 14/06/2016.
//  Copyright © 2016 Lofionic. All rights reserved.
//

import UIKit
import AVFoundation
import TapeDelayFramework


public protocol IAAWrapperDelegate {
    func iaaWrapperDidConnect(iaaWrapper : IAAWrapper)
    func iaaWrapperDidDisconnect(iaaWrapper : IAAWrapper)
}

public class IAAWrapper: NSObject {

    public var delegate : IAAWrapperDelegate?
    
    private let kSampleRate = 44100.0
    
    private var graph : AUGraph
    
    private var graphStarted : Bool
    private var isConnected  : Bool
    private var isForeground : Bool
    
    private var duplicatUnit : AudioUnit
    private var remoteIOUnit : AudioUnit
    
    internal func getAudioUnit() -> AudioUnit {
        return duplicatUnit
    }

    
    override init() {

        graph = nil;
        
        graphStarted    = false;
        isConnected     = false;
        isForeground    = false;
        
        duplicatUnit = nil;
        remoteIOUnit = nil;
        
        super.init()
        
        let appState = UIApplication.sharedApplication().applicationState
        isForeground = (appState != UIApplicationState.Background)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(appHasGoneInBackground),
                                                         name: UIApplicationDidEnterBackgroundNotification,
                                                         object: nil)
        
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(appHasGoneForeground),
                                                         name: UIApplicationWillEnterForegroundNotification,
                                                         object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(cleanup),
                                                         name: UIApplicationWillTerminateNotification,
                                                         object: nil)
        
    }
    
    func createAndPublish() {
        createGraph()
        addAudioUnitPropertyListeners()
        publishOutputAudioUnit()
        checkStartStopGraph()
    }
    
    private func createGraph() {
        CheckError(NewAUGraph(&graph), desc: "Creating AUGraph")
        
        // Register the Duplicat AU process
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Effect
        componentDescription.componentSubType = fourCharCodeFrom("dely")
        componentDescription.componentManufacturer = fourCharCodeFrom("LFDU")
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        AUAudioUnit.registerSubclass(TapeDelay.self, asComponentDescription: componentDescription, name: "Local Tape Delay", version: UInt32.max);
        
        // Remote IO description
        var ioUnitDescription = AudioComponentDescription()
        ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        ioUnitDescription.componentFlags = 0;
        ioUnitDescription.componentFlagsMask = 0;
        ioUnitDescription.componentType = kAudioUnitType_Output;
        ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;

        var remoteIONode = AUNode()
        CheckError(AUGraphAddNode(graph, &ioUnitDescription, &remoteIONode), desc:"Creating RemoteIO node")
        
        var duplicatNode = AUNode()
        CheckError(AUGraphAddNode(graph, &componentDescription, &duplicatNode), desc: "Creating Duplicat node")
        CheckError(AUGraphOpen(graph), desc: "Opening AUGraph");
        
        remoteIOUnit = nil
        CheckError(AUGraphNodeInfo(graph, remoteIONode, nil, &remoteIOUnit), desc:"Getting RemoteIO unit")
        
        // Grab the duplicat audio unit
        CheckError(AUGraphNodeInfo(graph, duplicatNode, nil, &duplicatUnit), desc: "Getting Duplicat unit")
        
        // Enable IO for recording
        var flag : UInt32 = 1
        CheckError(AudioUnitSetProperty(remoteIOUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,
            &flag,
            UInt32(sizeof(UInt32))),
                   desc: "Enabling IO for recording")
        
        CheckError(AudioUnitSetProperty(remoteIOUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,
            &flag,
            UInt32(sizeof(UInt32))),
                   desc: "Enabling IO for playback")
        
        // Required: Effect AudioUnit needs to be able to render max 4096 frames.
        var maxFrames : UInt32 = 4096;
        CheckError(AudioUnitSetProperty(duplicatUnit,
            kAudioUnitProperty_MaximumFramesPerSlice,
            kAudioUnitScope_Global,
            0,
            &maxFrames,
            UInt32(sizeof(UInt32))),
                   desc: "Setting AU max frames");
        
        var streamFormat : AudioStreamBasicDescription = AudioStreamBasicDescription()
        streamFormat.mChannelsPerFrame  = 2 // stereo
        streamFormat.mSampleRate        = AVAudioSession.sharedInstance().sampleRate
        streamFormat.mFormatID          = kAudioFormatLinearPCM
        streamFormat.mFormatFlags       = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        streamFormat.mBytesPerFrame 	= UInt32(sizeof(Float32))
        streamFormat.mBytesPerPacket    = UInt32(sizeof(Float32))
        streamFormat.mBitsPerChannel    = 32
        streamFormat.mFramesPerPacket   = 1
        
        CheckError(AudioUnitSetProperty(duplicatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, UInt32(sizeof(AudioStreamBasicDescription))), desc: "Setting duplicat output format")
        CheckError(AudioUnitSetProperty(duplicatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamFormat, UInt32(sizeof(AudioStreamBasicDescription))), desc: "Setting duplicat output format")
        CheckError(AudioUnitSetProperty(remoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamFormat, UInt32(sizeof(AudioStreamBasicDescription))), desc: "Setting RemoteIO output format")
        
        CheckError(AUGraphConnectNodeInput(graph, duplicatNode, 0, remoteIONode, 0), desc: "Connecting duplicat to RemoteIO")
        CheckError(AUGraphConnectNodeInput(graph, remoteIONode, 1, duplicatNode, 0), desc: "Connecting RemoteIO to duplicat")

    }
    
    private func addAudioUnitPropertyListeners() {
        
        var s : UnsafeMutablePointer<Void>;
        s = UnsafeMutablePointer(Unmanaged.passRetained(self).toOpaque())
        
        CheckError(AudioUnitAddPropertyListener(remoteIOUnit,
            kAudioUnitProperty_IsInterAppConnected,
            AudioUnitPropertyChangeDispatcher,
            s), desc: "Adding IsInterAppConnected property listener");
        CheckError(AudioUnitAddPropertyListener(remoteIOUnit,
            kAudioOutputUnitProperty_HostTransportState,
            AudioUnitPropertyChangeDispatcher,
            s), desc: "Adding HostTransportState property listener");
    }
    
    let AudioUnitPropertyChangeDispatcher : @convention(c) (inRefCon: UnsafeMutablePointer<Void>, inUnit: COpaquePointer, inID: UInt32, inScope: UInt32, inElement: UInt32) -> Void = {
        (inRefCon, inUnit, inID, inScope, inElement) in
        
        NSLog("[AudioUnitPropertyChangeDispatcher]");
 
        let SELF = Unmanaged<IAAWrapper>.fromOpaque(COpaquePointer(inRefCon)).takeUnretainedValue()

        SELF.audioUnitPropertyChangedListener(inRefCon, inUnit: inUnit, inPropID: inID, inScope: inScope, inElement: inElement)
    }

    func audioUnitPropertyChangedListener(inObject: UnsafeMutablePointer<Void>, inUnit:AudioUnit, inPropID: AudioUnitPropertyID, inScope: AudioUnitScope, inElement: AudioUnitElement) {
        if (inPropID == kAudioUnitProperty_IsInterAppConnected) {
            NSLog("PropertyChanged: IsInterAppConnected")
            isHostConnected()
            postUpdateStateNotification()
        } else if (inPropID == kAudioOutputUnitProperty_HostTransportState) {
            NSLog("PropertyChanged: HostTransportState")
            updateStateFromTransportCallBack()
            postUpdateStateNotification()
        }
    }
    
    private func publishOutputAudioUnit() {
        var desc = AudioComponentDescription(componentType: OSType(kAudioUnitType_RemoteEffect), componentSubType: fourCharCodeFrom("iasd"), componentManufacturer: fourCharCodeFrom("dupl"), componentFlags: 0, componentFlagsMask: 0);
        CheckError(
            AudioOutputUnitPublish(&desc, "Lofionic Duplicat", 1, remoteIOUnit),
            desc: "Publishing IAA Component");
    }
    
    private func checkStartStopGraph() {
        NSLog("[checkStartStopGraph]");
        if (isConnected) {
            if (!graphStarted) {
                setAudioSessionActive()
                if (graph != nil) {
                    var graphInitialized : DarwinBoolean = true
                    CheckError(AUGraphIsInitialized(graph, &graphInitialized), desc: "graphIsInitialized?")
                    if (!graphInitialized) {
                        CheckError(AUGraphInitialize(graph), desc: "Initializing AUGraph")
                    }
                    startGraph()
                }
            }
        } else {
            if (!isForeground) {
                if (graphStarted) {
                    stopGraph()
                    setAudioSessionInactive()
                }
            }
        }
    }
    
    private func startGraph() {
        NSLog("[startGraph]")
        if (!graphStarted) {
            if (graph != nil) {
                CheckError(AUGraphStart(graph), desc: "Starting graph")
                graphStarted = true;
            }
        }
    }
    
    private func stopGraph() {
        NSLog("[stopGraph]")
        if (graphStarted) {
            if (graph != nil) {
                CheckError(AUGraphStop(graph), desc: "Stopping graph")
                graphStarted = false;
            }
        }
    }
    
    private func setAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setPreferredSampleRate(kSampleRate);
            try session.setCategory(AVAudioSessionCategoryPlayback, withOptions: AVAudioSessionCategoryOptions.MixWithOthers)
            try session.setActive(true)
        } catch {
            NSLog("ERROR: setting audio session active")
        }
        
    }
    
    private func setAudioSessionInactive() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
        } catch {
            NSLog("ERROR: setting audio session inactive")
        }
    }
    
    @objc
    private func appHasGoneInBackground() {
        isForeground = false;
        checkStartStopGraph()
    }
    
    @objc
    private func appHasGoneForeground() {
        isForeground = true;
        isHostConnected()
        checkStartStopGraph()
        updateStateFromTransportCallBack()
    }
    
    @objc
    private func cleanup() {
        
    }
    
    private func isHostConnected() {
        if (remoteIOUnit != nil) {
            var data = UInt32(0)
            var dataSize = UInt32(sizeof(UInt32))
            CheckError(AudioUnitGetProperty(remoteIOUnit, kAudioUnitProperty_IsInterAppConnected, kAudioUnitScope_Global, 0, &data, &dataSize), desc: "AudioUnitGetProperty_IsInterAppConnected")
            let connect = (data > 0 ? true : false)
            if (connect != isConnected) {
                isConnected = connect
                if (isConnected) {
                    checkStartStopGraph()
                    getHostCallBackInfo()
                    getAudioUnitIcon()
                    if (delegate != nil) {
                        delegate?.iaaWrapperDidConnect(self)
                    }
                } else {
                    checkStartStopGraph()
                    if (delegate != nil) {
                        delegate?.iaaWrapperDidDisconnect(self)
                    }
                }
            }
            
        }
    }
    
    private func postUpdateStateNotification() {
        NSLog("[postUpdateStateNotification]")
    }
    
    private func getHostCallBackInfo() {
        NSLog("[getHostCallBackInfo]")
    }
    
    private func updateStateFromTransportCallBack() {
        NSLog("[updateStateFromTransportCallBack]")
    }
    
    private func getAudioUnitIcon() {
        NSLog("[getAudioUnitIcon]")
    }
    
    private func fourCharCodeFrom(string : String) -> FourCharCode
    {
        assert(string.characters.count == 4, "String length must be 4")
        var result : FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
    
    private func CheckError(error:OSStatus, desc:String) {
        if error == 0 {return}
        
        print (desc);
        switch(error) {
        // AudioToolbox
        case kAUGraphErr_NodeNotFound:
            print("Error:kAUGraphErr_NodeNotFound")
            
        case kAUGraphErr_OutputNodeErr:
            print( "Error:kAUGraphErr_OutputNodeErr")
            
        case kAUGraphErr_InvalidConnection:
            print("Error:kAUGraphErr_InvalidConnection")
            
        case kAUGraphErr_CannotDoInCurrentContext:
            print( "Error:kAUGraphErr_CannotDoInCurrentContext")
            
        case kAUGraphErr_InvalidAudioUnit:
            print( "Error:kAUGraphErr_InvalidAudioUnit")
            
            //    case kMIDIInvalidClient :
            //        print( "kMIDIInvalidClient ")
            //
            //
            //    case kMIDIInvalidPort :
            //        print( "kMIDIInvalidPort ")
            //
            //
            //    case kMIDIWrongEndpointType :
            //        print( "kMIDIWrongEndpointType")
            //
            //
            //    case kMIDINoConnection :
            //        print( "kMIDINoConnection ")
            //
            //
            //    case kMIDIUnknownEndpoint :
            //        print( "kMIDIUnknownEndpoint ")
            //
            //
            //    case kMIDIUnknownProperty :
            //        print( "kMIDIUnknownProperty ")
            //
            //
            //    case kMIDIWrongPropertyType :
            //        print( "kMIDIWrongPropertyType ")
            //
            //
            //    case kMIDINoCurrentSetup :
            //        print( "kMIDINoCurrentSetup ")
            //
            //
            //    case kMIDIMessageSendErr :
            //        print( "kMIDIMessageSendErr ")
            //
            //
            //    case kMIDIServerStartErr :
            //        print( "kMIDIServerStartErr ")
            //
            //
            //    case kMIDISetupFormatErr :
            //        print( "kMIDISetupFormatErr ")
            //
            //
            //    case kMIDIWrongThread :
            //        print( "kMIDIWrongThread ")
            //
            //
            //    case kMIDIObjectNotFound :
            //        print( "kMIDIObjectNotFound ")
            //
            //
            //    case kMIDIIDNotUnique :
            //        print( "kMIDIIDNotUnique ")
            
            
        case kAudioToolboxErr_InvalidSequenceType :
            print( " kAudioToolboxErr_InvalidSequenceType")
            
        case kAudioToolboxErr_TrackIndexError :
            print( " kAudioToolboxErr_TrackIndexError")
            
        case kAudioToolboxErr_TrackNotFound :
            print( " kAudioToolboxErr_TrackNotFound")
            
        case kAudioToolboxErr_EndOfTrack :
            print( " kAudioToolboxErr_EndOfTrack")
            
        case kAudioToolboxErr_StartOfTrack :
            print( " kAudioToolboxErr_StartOfTrack")
            
        case kAudioToolboxErr_IllegalTrackDestination	:
            print( " kAudioToolboxErr_IllegalTrackDestination")
            
        case kAudioToolboxErr_NoSequence 		:
            print( " kAudioToolboxErr_NoSequence")
            
        case kAudioToolboxErr_InvalidEventType		:
            print( " kAudioToolboxErr_InvalidEventType")
            
        case kAudioToolboxErr_InvalidPlayerState	:
            print( " kAudioToolboxErr_InvalidPlayerState")
            
        case kAudioUnitErr_InvalidProperty		:
            print( " kAudioUnitErr_InvalidProperty")
            
        case kAudioUnitErr_InvalidParameter		:
            print( " kAudioUnitErr_InvalidParameter")
            
        case kAudioUnitErr_InvalidElement		:
            print( " kAudioUnitErr_InvalidElement")
            
        case kAudioUnitErr_NoConnection			:
            print( " kAudioUnitErr_NoConnection")
            
        case kAudioUnitErr_FailedInitialization		:
            print( " kAudioUnitErr_FailedInitialization")
            
        case kAudioUnitErr_TooManyFramesToProcess	:
            print( " kAudioUnitErr_TooManyFramesToProcess")
            
        case kAudioUnitErr_InvalidFile			:
            print( " kAudioUnitErr_InvalidFile")
            
        case kAudioUnitErr_FormatNotSupported		:
            print( " kAudioUnitErr_FormatNotSupported")
            
        case kAudioUnitErr_Uninitialized		:
            print( " kAudioUnitErr_Uninitialized")
            
        case kAudioUnitErr_InvalidScope			:
            print( " kAudioUnitErr_InvalidScope")
            
        case kAudioUnitErr_PropertyNotWritable		:
            print( " kAudioUnitErr_PropertyNotWritable")
            
        case kAudioUnitErr_InvalidPropertyValue		:
            print( " kAudioUnitErr_InvalidPropertyValue")
            
        case kAudioUnitErr_PropertyNotInUse		:
            print( " kAudioUnitErr_PropertyNotInUse")
            
        case kAudioUnitErr_Initialized			:
            print( " kAudioUnitErr_Initialized")
            
        case kAudioUnitErr_InvalidOfflineRender		:
            print( " kAudioUnitErr_InvalidOfflineRender")
            
        case kAudioUnitErr_Unauthorized			:
            print( " kAudioUnitErr_Unauthorized")
            
        default:
            print("huh?")
        }
    }
}
