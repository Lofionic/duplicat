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

class ViewController: UIViewController {
    
    @IBOutlet var auContainerView       : UIView!
    @IBOutlet var backgroundImageView   : UIImageView!
    @IBOutlet var auContainerBevelView  : UIImageView!
    
    @IBOutlet var playButton    : UIButton!
    
    var duplicatViewController  : TapeDelayViewController!
    var playEngine              : SimplePlayEngine!

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
}

