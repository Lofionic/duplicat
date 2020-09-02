//
//  IAAWrapper.swift
//  Duplicat
//
//  Created by Chris Rivers on 14/06/2016.
//  Copyright © 2016 Lofionic. All rights reserved.
//

import UIKit
import AVFoundation
import DuplicatFramework

let kIAATransportStateChangedNotification:String = "IAATransportStateChangedNotification"

protocol IAAWrapperDelegate {
    func audioUnitDidConnect(_ iaaWrapper : IAAWrapper, audioUnit : AUAudioUnit?)
}

open class IAAWrapper: NSObject {

    var delegate : IAAWrapperDelegate?
    
    fileprivate let kSampleRate = 44100.0
    
    fileprivate var avEngine : AVAudioEngine
    fileprivate var audioUnit : AVAudioUnit?
    
    fileprivate var graphStarted : Bool
    fileprivate var isIAAConnected  : Bool
    fileprivate var isForeground : Bool
    
    fileprivate var isAudiobusSession : Bool
    fileprivate var isAudiobusConnected : Bool
        
    fileprivate(set) open var isPlaying : Bool
    fileprivate(set) open var isRecording : Bool
    
    fileprivate var callbackInfo : UnsafeMutablePointer<HostCallbackInfo>?
    
    fileprivate var hostIcon : UIImage?
    
    fileprivate var audioBusController : ABAudiobusController?
    fileprivate var audioBusfilterPort : ABAudioFilterPort?
    
    internal func getAudioUnit() -> AudioUnit {
        return self.audioUnit!.audioUnit
    }

    override init() {
        avEngine = AVAudioEngine()
        
        graphStarted = false
        isIAAConnected = false
        isForeground = false
        
        isAudiobusConnected = false
        isAudiobusSession = false
        
        callbackInfo = nil
        
        isPlaying = false
        isRecording = false
                
        super.init()
        
        let appState = UIApplication.shared.applicationState
        isForeground = (appState != UIApplication.State.background)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appHasGoneInBackground),  name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appHasGoneForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cleanup), name: UIApplication.willTerminateNotification, object: nil)
        
        NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { [weak self] note in
            print("Audio services reset")
            self?.cleanup()
            self?.createAndPublish()
        }
    }
    
    func createAndPublish() {
        print(#function)
        createAudioUnit()
        addAudioUnitPropertyListeners()
        publishOutputAudioUnit()
        publishAudiobus()
    }
    
    private func createAudioUnit() {
        print(#function)
        var localComponentDescription = AudioComponentDescription()
        localComponentDescription.componentType = kIAAComponentType
        localComponentDescription.componentSubType = fourCharCodeFrom(string: kIAAComponentSubtype)
        localComponentDescription.componentManufacturer = fourCharCodeFrom(string: kIAAComponentManufacturer)
        localComponentDescription.componentFlags = 0
        localComponentDescription.componentFlagsMask = 0
        AUAudioUnit.registerSubclass(TapeDelay.self, as: localComponentDescription, name: "Local Tape Delay", version: UInt32.max);
        
        var effectComponentDescription = AudioComponentDescription()
        effectComponentDescription.componentType = kIAAComponentType
        effectComponentDescription.componentSubType = fourCharCodeFrom(string: kIAAComponentSubtype)
        effectComponentDescription.componentManufacturer = fourCharCodeFrom(string: kIAAComponentManufacturer)
        
        AVAudioUnit.instantiate(with: effectComponentDescription, options: []) { [weak self] avAudioUnit, error in
            guard let self = self, let avAudioUnit = avAudioUnit else { return }
            self.avEngine.attach(avAudioUnit)
            
            var maxFrames : UInt32 = 4096;
            self.CheckError(
                error: AudioUnitSetProperty(
                    avAudioUnit.audioUnit,
                    kAudioUnitProperty_MaximumFramesPerSlice,
                    kAudioUnitScope_Global,
                    0,
                    &maxFrames,
                    UInt32(MemoryLayout<UInt32>.size)),
                desc: "Setting AU max frames");
            
            self.avEngine.connect(avAudioUnit, to: self.avEngine.outputNode, format: nil)
            
            self.audioUnit = avAudioUnit
            self.audioUnitDidConnect()
        }
    }
    
    private func audioUnitDidConnect() {
        print(#function)
        if let delegate = self.delegate {
            delegate.audioUnitDidConnect(self, audioUnit: self.audioUnit?.auAudioUnit)
        }
        
        checkStartStopGraph()
    }
    
    private func addAudioUnitPropertyListeners() {
        print(#function)
        var s : UnsafeMutableRawPointer;
        s = Unmanaged.passRetained(self).toOpaque()
        
        let inputNode = self.avEngine.inputNode
    
        CheckError(error: AudioUnitAddPropertyListener(inputNode.audioUnit!,
            kAudioUnitProperty_IsInterAppConnected,
            AudioUnitPropertyChangeDispatcher,
            s), desc: "Adding IsInterAppConnected property listener");
        CheckError(error: AudioUnitAddPropertyListener(inputNode.audioUnit!,
            kAudioOutputUnitProperty_HostTransportState,
            AudioUnitPropertyChangeDispatcher,
            s), desc: "Adding HostTransportState property listener");
    }
    
    let AudioUnitPropertyChangeDispatcher : @convention(c) (UnsafeMutableRawPointer, OpaquePointer, UInt32, UInt32, UInt32) -> Void = {
        (inRefCon, inUnit, inID, inScope, inElement) in
        print(#function)
        
        let SELF = Unmanaged<IAAWrapper>.fromOpaque(inRefCon).takeUnretainedValue()
        SELF.audioUnitPropertyChangedListener(inRefCon, inUnit: inUnit, inPropID: inID, inScope: inScope, inElement: inElement)
    }

    func audioUnitPropertyChangedListener(_ inObject: UnsafeMutableRawPointer, inUnit:AudioUnit, inPropID: AudioUnitPropertyID, inScope: AudioUnitScope, inElement: AudioUnitElement) {
        if (inPropID == kAudioUnitProperty_IsInterAppConnected) {
            checkIsHostConnected()
            postUpdateStateNotification()
        } else if (inPropID == kAudioOutputUnitProperty_HostTransportState) {
            updateStateFromTransportCallBack()
            postUpdateStateNotification()
        }
    }
    
    fileprivate func publishOutputAudioUnit() {
        print(#function)
        let inputNode = avEngine.inputNode
        
        var desc = AudioComponentDescription(componentType: OSType(kIAAComponentType), componentSubType: fourCharCodeFrom(string: kIAAComponentSubtype), componentManufacturer: fourCharCodeFrom(string: kIAAComponentManufacturer), componentFlags: 0, componentFlagsMask: 0);
        CheckError(
            error: AudioOutputUnitPublish(&desc, "Lofionic Duplicat" as CFString, 4, inputNode.audioUnit!),
            desc: "Publishing IAA Component");
    }
    
    fileprivate func publishAudiobus() {
        // Create the audiodus controller
        self.audioBusController = ABAudiobusController(apiKey: kAudiobusKey)
        self.audioBusController?.stateIODelegate = self
        self.audioBusController?.connectionPanelPosition = ABConnectionPanelPositionLeft
        
        // Create the audiobus filter port
        let desc = AudioComponentDescription(componentType: OSType(kIAAComponentType), componentSubType: fourCharCodeFrom(string: kIAAComponentSubtype), componentManufacturer: fourCharCodeFrom(string: kIAAComponentManufacturer), componentFlags: 0, componentFlagsMask: 0);
        audioBusfilterPort = ABAudioFilterPort(name: "Lofionic Duplicat", title: "Main Port", audioComponentDescription: desc, audioUnit: avEngine.outputNode.audioUnit)
        audioBusController?.addAudioFilterPort(audioBusfilterPort)
        
        NotificationCenter.default.addObserver(self, selector: #selector(audiobusConnectionsChangedNotifactionReceived), name: NSNotification.Name.ABConnectionsChanged, object: audioBusController)
    }
    
    @objc
    private func audiobusConnectionsChangedNotifactionReceived(note : NSNotification) {
        print(#function)
        if let audiobus = audioBusController {
            isAudiobusConnected = audiobus.audiobusConnected
            isAudiobusSession = audiobus.memberOfActiveAudiobusSession
        }
        checkStartStopGraph()
    }
    
    private func checkStartStopGraph() {
        print(#function)
        print("isIAAConnected: \(isIAAConnected)")
        print("isAudiobusConnected: \(isAudiobusConnected)")
        print("isForeground: \(isForeground)")
        print("isAudiobusSession: \(isAudiobusSession)")
        
        if isIAAConnected || isAudiobusConnected {
            if (!graphStarted) {
                setAudioSessionActive()
                startGraph()
            }
        } else {
            if (!isForeground && !isAudiobusSession) {
                if (graphStarted) {
                    stopGraph()
                    setAudioSessionInactive()
                }
            }
        }
    }
    
    private func startGraph() {
        print(#function)
        
        if let audioUnit = self.audioUnit {
            self.avEngine.disconnectNodeInput(audioUnit)
            self.avEngine.connect(self.avEngine.inputNode, to: audioUnit, format: audioUnit.inputFormat(forBus: 0))
        }
        
        do {
            try avEngine.start()
            graphStarted = true
        } catch {
            print("Failed to start engine: \(error)")
        }
    }
    
    private func stopGraph() {
        print(#function)
        
        let inputNode = self.avEngine.inputNode
        self.avEngine.disconnectNodeOutput(inputNode)
        
        avEngine.pause()
        graphStarted = false
    }
    
    private func setAudioSessionActive() {
        print(#function)
        
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setPreferredSampleRate(kSampleRate);
            try session.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.mixWithOthers)
            try session.setActive(true)
        } catch {
            print("Unable to set AVAudioSession active: \(error)")
        }
    }
    
    private func setAudioSessionInactive() {
        print(#function)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
        } catch {
            print("Unable to set AVAudioSession inactive: \(error)")
        }
    }
    
    @objc
    private func appHasGoneForeground() {
        print(#function)
        isForeground = true;
        checkIsHostConnected()
        checkStartStopGraph()
        updateStateFromTransportCallBack()
    }
    
    @objc
    private func appHasGoneInBackground() {
        print(#function)
        isForeground = false;
        checkStartStopGraph()
    }
    
    @objc
    private func cleanup() {
        print(#function)
        stopGraph()
        avEngine.stop()
        setAudioSessionInactive()
    }
    
    private func checkIsHostConnected() {
        print(#function)
        
        let inputNode = self.avEngine.inputNode
        var data = UInt32(0)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        CheckError(
            error: AudioUnitGetProperty(
                inputNode.audioUnit!,
                kAudioUnitProperty_IsInterAppConnected,
                kAudioUnitScope_Global,
                0,
                &data,
                &dataSize),
            desc: "AudioUnitGetProperty_IsInterAppConnected")
        
        let connect = (data > 0 ? true : false)
        
        if (connect != isIAAConnected) {
            isIAAConnected = connect
            if (isIAAConnected) {
                print("IAA did connect")
                checkStartStopGraph()
                getHostCallBackInfo()
                getAudioUnitIcon()
            } else {
                NSLog("IAA did disconnect")
                checkStartStopGraph()
            }
        }
    }
    
    private func postUpdateStateNotification() {
        print(#function)
        DispatchQueue.main.async(execute: {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kIAATransportStateChangedNotification), object: self)
        })
    }
    
    private func getHostCallBackInfo() {
        NSLog("[getHostCallBackInfo]")
        if (isIAAConnected) {
            if (callbackInfo != nil) {
                free(callbackInfo)
            }
        
            let inputNode = self.avEngine.inputNode
            var datasize = UInt32(MemoryLayout<HostCallbackInfo>.size)
            //callbackInfo = UnsafeMutableRawPointer<HostCallbackInfo>(malloc(sizeof(HostCallbackInfo)))
            
            //callbackInfo = UnsafeMutableRawPointer(malloc(sizeof(HostCallbackInfo))
            
            // callbackInfo = UnsafeMutablePointer<HostCallbackInfo>(malloc(sizeof(HostCallbackInfo)))
            callbackInfo = UnsafeMutablePointer<HostCallbackInfo>.allocate(capacity: MemoryLayout<HostCallbackInfo>.size)
            
            let result = AudioUnitGetProperty(inputNode.audioUnit!, kAudioUnitProperty_HostCallbacks, kAudioUnitScope_Global, 0, callbackInfo!, &datasize)
            if (result != noErr) {
                free(callbackInfo)
                callbackInfo = nil
            }
        }
    }
    
    // This is called when the app enters the foreground, or when the host transport state is changed.
    private func updateStateFromTransportCallBack() {
        // Transport state will only be updated when the app is connected and in the foreground.
        if (isIAAConnected && isForeground) {
            if (callbackInfo == nil) {
                getHostCallBackInfo()
            }
            
            if (callbackInfo != nil) {
                let hostPlaying = UnsafeMutablePointer<DarwinBoolean>.allocate(capacity: 1)
                hostPlaying[0] = isPlaying ? true : false
                
                let hostRecording = UnsafeMutablePointer<DarwinBoolean>.allocate(capacity: 1)
                hostRecording[0] = isRecording ? true : false
                
                var outCurrentSampleInTimeLine = Float64(0)
                
                let hostUserData = callbackInfo?.pointee.hostUserData
                let transportStateProc = callbackInfo?.pointee.transportStateProc2
                if let transportStateProcUnwrapped = transportStateProc {
                    let result = transportStateProcUnwrapped(hostUserData,
                                                             hostPlaying,
                                                             hostRecording,
                                                             nil,
                                                             &outCurrentSampleInTimeLine,
                                                             nil,
                                                             nil,
                                                             nil)
                    
                    if (result == noErr) {
                        isPlaying = hostPlaying.pointee.boolValue
                        isRecording = hostRecording.pointee.boolValue
                    }
                }
            }
        }
    }
    
    public func sendStateToRemoteHost(event: AudioUnitRemoteControlEvent) {
        let inputNode = self.avEngine.inputNode
        var controlEvent = event.rawValue
        let dataSize = UInt32(MemoryLayout<AudioUnitRemoteControlEvent>.size)
        CheckError(error: AudioUnitSetProperty(inputNode.audioUnit!, kAudioOutputUnitProperty_RemoteControlToHost, kAudioUnitScope_Global, 0, &controlEvent, dataSize), desc: "Sending remote control event")
    }
    
    private func getAudioUnitIcon() {
        NSLog("[getAudioUnitIcon]")
        let inputNode = self.avEngine.inputNode
        hostIcon = AudioOutputUnitGetHostIcon(inputNode.audioUnit!, 100);
    }
    
    private func fourCharCodeFrom(string : String) -> FourCharCode
    {
        assert(string.count == 4, "String length must be 4")
        var result : FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
    
    public func CheckError(error:OSStatus, desc:String) {
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

extension IAAWrapper : IAATransportViewDelegate {
    
    public func isHostPlaying() -> Bool {
        return isPlaying
    }
    
    public func isHostConnected() -> Bool {
        return isIAAConnected && !isAudiobusConnected
    }
    
    public func isHostRecording() -> Bool {
        return isRecording
    }
    
    public func getHostIcon() -> UIImage? {
        return hostIcon
    }
    
    public func goToHost() {
        let inputNode = self.avEngine.inputNode
        var instrumentUrl = CFURLCreateWithString(nil, nil, nil)!
        var dataSize = UInt32(MemoryLayout<CFURL>.size)
        CheckError(error: AudioUnitGetProperty(inputNode.audioUnit!, kAudioUnitProperty_PeerURL, kAudioUnitScope_Global, 0, &instrumentUrl, &dataSize), desc: "Getting PeerURL Property")
        UIApplication.shared.openURL(instrumentUrl as URL)
    }
    
    public func canPlay() -> Bool {
        return isIAAConnected
    }
    
    public func canRewind() -> Bool {
        return isIAAConnected
    }
    
    public func canRecord() -> Bool {
        return !isPlaying
    }

    public func hostRewind() {
        sendStateToRemoteHost(event: .rewind)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kIAATransportStateChangedNotification), object: self)
    }
    
    public func hostPlay() {
        sendStateToRemoteHost(event: .togglePlayPause)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kIAATransportStateChangedNotification), object: self)
    }
    
    public func hostRecord() {
        sendStateToRemoteHost(event: .toggleRecord)
        NotificationCenter.default.post(name: Notification.Name(rawValue: kIAATransportStateChangedNotification), object: self)
    }
}

extension IAAWrapper : ABAudiobusControllerStateIODelegate {
    
    public func audiobusStateDictionaryForCurrentState() -> [AnyHashable: Any]! {

        if let effectNode = self.audioUnit {
            // Fetch the parameter IDs from the AudioUnit
            // These IDs will be used to get & set parameters
            var size: UInt32 = 0
            var propertyBool = DarwinBoolean(true)
            AudioUnitGetPropertyInfo(
                effectNode.audioUnit,
                kAudioUnitProperty_ParameterList,
                kAudioUnitScope_Global,
                0,
                &size,
                &propertyBool)
            let numParams = Int(size)/MemoryLayout<AudioUnitParameterID>.size
            var paramIDs = [AudioUnitParameterID](repeating: 0, count: Int(numParams))
            AudioUnitGetProperty(
                effectNode.audioUnit,
                kAudioUnitProperty_ParameterList,
                kAudioUnitScope_Global,
                0,
                &paramIDs,
                &size)
        
            let stateDictionary = NSMutableDictionary.init(capacity: paramIDs.count)
            for paramID in paramIDs {
                
                var value = AudioUnitParameterValue(0)
                AudioUnitGetParameter(effectNode.audioUnit, paramID, kAudioUnitScope_Global, 0, &value)
                
                stateDictionary.setValue(value, forKey: String(paramID))
            }
        
            return NSDictionary.init(dictionary: stateDictionary) as? [AnyHashable : Any]
        } else {
            return NSDictionary() as? [AnyHashable: Any]
        }
    }
    
    public func loadState(fromAudiobusStateDictionary dictionary: [AnyHashable: Any]!, responseMessage outResponseMessage: AutoreleasingUnsafeMutablePointer<NSString?>) {
        
        if let effectNode = self.audioUnit {
            let stateDictionary = dictionary as NSDictionary
            for thisKey in stateDictionary.allKeys {
                let paramId = UInt32(thisKey as! String)
                
                if let paramId = paramId {
                    let value = stateDictionary.object(forKey: thisKey) as! AudioUnitParameterValue
                    AudioUnitSetParameter(effectNode.audioUnit, paramId, kAudioUnitScope_Global, 0, value, 0)
                }
            }
        }
    }
}

// Some useful code for fetching parameter IDs from an audio unit.
//    func connectViewWithAU(audioUnit: AudioUnit?) {
//
//        // Fetch the parameter IDs from the AudioUnit
//        // These IDs will be used to get & set parameters
//        var size: UInt32 = 0
//        var propertyBool = DarwinBoolean(true)
//        AudioUnitGetPropertyInfo(
//            audioUnit!,
//            kAudioUnitProperty_ParameterList,
//            kAudioUnitScope_Global,
//            0,
//            &size,
//            &propertyBool)
//        let numParams = Int(size)/sizeof(AudioUnitParameterID)
//        paramIDs = [AudioUnitParameterID](count: Int(numParams), repeatedValue: 0)
//        AudioUnitGetProperty(
//            audioUnit!,
//            kAudioUnitProperty_ParameterList,
//            kAudioUnitScope_Global,
//            0,
//            &paramIDs,
//            &size)
//
//        updateTapeSpeedControl();
//        updateMixControl();
//        updateFeedbackControl();
//        updateTapeEffectControl();
//
//        updateDelayButtons();
//    }

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
