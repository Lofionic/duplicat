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

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet var auContainerView       : UIView!
    @IBOutlet var backgroundImageView   : UIImageView!
    @IBOutlet var auContainerBevelView  : UIImageView!
    
    @IBOutlet var playButton    : UIButton!
    
    var duplicatViewController  : TapeDelayViewController!
    var playEngine              : SimplePlayEngine!

    struct AudioSample {
        
        var title           : String!
        var filename        : String!
        var fileExtension   : String!
        
        init(title: String, filename: String, fileExtension: String) {
            self.title = title;
            self.filename = filename;
            self.fileExtension = fileExtension;
        }
    }
    
    var audioSamples = [AudioSample]()
    
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
        
        playEngine = SimplePlayEngine()
        
        // Register the AU process
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Effect
        componentDescription.componentSubType = fourCharCodeToOSType("dely")
        componentDescription.componentManufacturer = fourCharCodeToOSType("LFDU")
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        AUAudioUnit.registerSubclass(TapeDelay.self, asComponentDescription: componentDescription, name: "Local Tape Delay", version: UInt32.max);
        
        // Instantiate and insert our audio unit effect into the chain.
        playEngine.selectEffectWithComponentDescription(componentDescription) {
            // This is an asynchronous callback when complete. Finish audio unit setup.
            // self.connectParametersToControls()
            self.duplicatViewController.audioUnit = self.playEngine.audioUnit as? TapeDelay;
        }
        
        // Set up the audio samples
        audioSamples = [
            AudioSample(title: "Drums", filename: "drumLoop", fileExtension: "caf"),
            AudioSample(title: "Guitar", filename: "gtrLoop", fileExtension: "wav"),
            AudioSample(title: "Vocals", filename: "drumLoop", fileExtension: "caf"),
            AudioSample(title: "Synth", filename: "gtrLoop", fileExtension: "wav")
        ]
        
        //        guard let fileURL = NSBundle.mainBundle().URLForResource("gtrLoop", withExtension: "wav") else {
        //            fatalError("\"drumLoop.caf\" file not found.")
        //        }
        
//         setPlayerFile(fileURL)
        
        selectAudioSampleAtIndex(0);
    }
    
    func selectAudioSampleAtIndex(index: Int) {
        let selectedAudioSample = audioSamples[index]
        guard let fileURL = NSBundle.mainBundle().URLForResource(selectedAudioSample.filename, withExtension: selectedAudioSample.fileExtension) else {
            fatalError("AudioSample file not found.")
        }
        
        playEngine.setPlayerFile(fileURL)
        
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
    
    /// Handles Play/Stop button touches.
    @IBAction func togglePlay(sender: AnyObject?) {
        let isPlaying = playEngine.togglePlay()
        
        let titleText = isPlaying ? "Stop" : "Play"
        
        playButton.setTitle(titleText, forState: .Normal)
    }
    
    //// UIPickerView
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1;
    }
 
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return audioSamples.count;
    }
    
    func pickerView(pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let string = audioSamples[row].title
        return NSAttributedString(string: string, attributes: [NSForegroundColorAttributeName:UIColor.whiteColor()])
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectAudioSampleAtIndex(row);
    }
}


