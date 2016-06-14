//
//  ViewController.swift
//  Duplicat
//
//  Created by Chris on 13/08/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//

import UIKit
import TapeDelayFramework
import AudioToolbox
import AVFoundation

class ViewController: UIViewController {
    
    let kSampleRate = 44100.0
    
    @IBOutlet var auContainerView       : UIView!
    @IBOutlet var backgroundImageView   : UIImageView!
    @IBOutlet var auContainerBevelView  : UIImageView!
    
    @IBOutlet var playButton    : UIButton!
    
    var duplicatViewController  : TapeDelayViewController!
    var duplicatUnit            : AudioUnit = nil
    var remoteIOUnit            : AudioUnit = nil
    
    var graph : AUGraph = nil
    
    var graphStarted    : Bool = false
    var isConnected     : Bool = false
    var isForeground    : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let backgroundImage = backgroundImageView.image {
            backgroundImageView.image = backgroundImage.resizableImageWithCapInsets(UIEdgeInsetsZero, resizingMode: UIImageResizingMode.Tile);
        }
        
        if let auContainerBevelBackgroundImage = auContainerBevelView.image {
            auContainerBevelView.image = auContainerBevelBackgroundImage.resizableImageWithCapInsets(UIEdgeInsetsMake(8, 8, 8, 8), resizingMode: UIImageResizingMode.Stretch);
        }
        
        embedPlugInView()
        createGraph()
        addAudioUnitPropertyListeners()
        publishOutputAudioUnit()
        checkStartStopGraph()
    }
    
    func createGraph() {
        
        CheckError(NewAUGraph(&graph), desc: "Creating AUGraph")
        
        // Register the Duplicat AU process
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Effect
        componentDescription.componentSubType = fourCharCodeToOSType("dely")
        componentDescription.componentManufacturer = fourCharCodeToOSType("LFDU")
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
        duplicatUnit = nil
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
        
        var streamFormat : AudioStreamBasicDescription = AudioStreamBasicDescription()
        streamFormat.mChannelsPerFrame  = 2 // stereo
        streamFormat.mSampleRate        = AVAudioSession.sharedInstance().sampleRate
        streamFormat.mFormatID          = kAudioFormatLinearPCM
        streamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved
        streamFormat.mBytesPerFrame 	= UInt32(sizeof(Float32))
        streamFormat.mBytesPerPacket    = UInt32(sizeof(Float32))
        streamFormat.mBitsPerChannel    = 32
        streamFormat.mFramesPerPacket   = 1
        
        CheckError(AudioUnitSetProperty(duplicatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamFormat, UInt32(sizeof(AudioStreamBasicDescription))), desc: "Setting duplicat output format")
        
        CheckError(AudioUnitSetProperty(remoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamFormat, UInt32(sizeof(AudioStreamBasicDescription))), desc: "Setting RemoteIO output format")

        CheckError(AUGraphConnectNodeInput(graph, duplicatNode, 0, remoteIONode, 0), desc: "Connecting duplicat to RemoteIO")
        CheckError(AUGraphConnectNodeInput(graph, remoteIONode, 1, duplicatNode, 0), desc: "Connecting RemoteIO to duplicat")
    }
    
    func addAudioUnitPropertyListeners() {
        // TODO
//        Check(AudioUnitAddPropertyListener(outputUnit,
//            kAudioUnitProperty_IsInterAppConnected,
//            AudioUnitPropertyChangeDispatcher,
//            self));
//        Check(AudioUnitAddPropertyListener(outputUnit,
//            kAudioOutputUnitProperty_HostTransportState,
//            AudioUnitPropertyChangeDispatcher,
//            self));
    }
    
    func publishOutputAudioUnit() {
        var desc = AudioComponentDescription(componentType: OSType(kAudioUnitType_RemoteEffect), componentSubType: fourCharCodeFrom("iasd"), componentManufacturer: fourCharCodeFrom("dupl"), componentFlags: 0, componentFlagsMask: 0);
        CheckError(
            AudioOutputUnitPublish(&desc, "Lofionic Duplicat", 1, remoteIOUnit),
            desc: "Publishing IAA Component");
    }
    
    func checkStartStopGraph() {
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
    
    func startGraph() {
        NSLog("[startGraph]")
        if (!graphStarted) {
            if (graph != nil) {
                CheckError(AUGraphStart(graph), desc: "Starting graph")
                graphStarted = true;
            }
        }
    }
    
    func stopGraph() {
        NSLog("[stopGraph]")
        if (graphStarted) {
            if (graph != nil) {
                CheckError(AUGraphStop(graph), desc: "Stopping graph")
                graphStarted = false;
            }
        }
    }
    
    func setAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setPreferredSampleRate(kSampleRate);
            try session.setCategory(AVAudioSessionCategoryPlayback, withOptions: AVAudioSessionCategoryOptions.MixWithOthers)
            try session.setActive(true)
        } catch {
            
        }

    }
    
    func setAudioSessionInactive() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
        } catch {
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /// Called from `viewDidLoad(_:)` to embed the plug-in's view into the app's view.
    func embedPlugInView() {
        /*
        Locate the app extension's bundle, in the app bundle's PlugIns
        subdirectory. Load its MainInterface storyboard, and obtain the
        `FilterDemoViewController` from that.
        */
        let builtInPlugInsURL = NSBundle.mainBundle().builtInPlugInsURL!
        let pluginURL = builtInPlugInsURL.URLByAppendingPathComponent("TapeDelayAppex.appex")
        let appExtensionBundle = NSBundle(URL: pluginURL)
        
        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)
        duplicatViewController = storyboard.instantiateInitialViewController() as! TapeDelayViewController

        // Present the view controller's view.
        if let view = duplicatViewController.view {
            addChildViewController(duplicatViewController)
            view.frame = auContainerView.bounds
            view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            
            auContainerView.addSubview(view)
            duplicatViewController.didMoveToParentViewController(self)
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent;
    }
    
    func fourCharCodeToOSType(inCode: NSString) -> OSType
    {
        var rval: OSType = 0
        let data = inCode.dataUsingEncoding(NSMacOSRomanStringEncoding)
        
        if let theData = data {
            theData.getBytes(&rval, length: sizeof(OSType))
        }
        return rval;
    }
    
    func fourCharCodeFrom(string : String) -> FourCharCode
    {
        assert(string.characters.count == 4, "String length must be 4")
        var result : FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
    
    func CheckError(error:OSStatus) {
        CheckError(error, desc: "Anonymous")
    }

    func CheckError(error:OSStatus, desc:String) {
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


