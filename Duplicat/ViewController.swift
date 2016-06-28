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

    @IBOutlet var auContainerView           : UIView!
    @IBOutlet var backgroundImageView       : UIImageView!
    @IBOutlet var auContainerBevelView      : UIImageView!
    
    @IBOutlet var transportView : IAATransportView!
    
    var duplicatViewController  : TapeDelayViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure resizable images in UI
        if let backgroundImage = backgroundImageView.image {
            backgroundImageView.image = backgroundImage.resizableImageWithCapInsets(UIEdgeInsetsZero, resizingMode: UIImageResizingMode.Tile);
        }
        
        if let auContainerBevelBackgroundImage = auContainerBevelView.image {
            auContainerBevelView.image = auContainerBevelBackgroundImage.resizableImageWithCapInsets(UIEdgeInsetsMake(8, 8, 8, 8), resizingMode: UIImageResizingMode.Stretch);
        }

        // Embed the effect's plugin view
         embedPlugInView()

        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let iaaWrapper = appDelegate.iaaWrapper
        
        if let iaaWrapper = iaaWrapper {
            
            // Create the iaaWrapper and publish it for IAA
            iaaWrapper.delegate = self
            iaaWrapper.createAndPublish()
            
            // Link transport view to the iaaWrapper
            transportView.delegate = iaaWrapper
            
            // Link effect's view controller to the iaaWrapper's audio unit
//            duplicatViewController.audioUnit = iaaWrapper.getAudioUnit()
            
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

}

extension ViewController : IAAWrapperDelegate {
    func audioUnitDidConnect(iaaWrapper: IAAWrapper, audioUnit : AUAudioUnit?) {
        if let audioUnit = audioUnit  {
            duplicatViewController.tapeDelayAudioUnit = (audioUnit as! TapeDelay)
        }
    }
}

