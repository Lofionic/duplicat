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
    
    @IBOutlet var auContainerView           : UIView!
    @IBOutlet var backgroundImageView       : UIImageView!
    @IBOutlet var auContainerBevelView      : UIImageView!
    
    @IBOutlet var iaaControlContainerView       : UIView!
    @IBOutlet var iaaControlHostIconImageView   : UIImageView!
    
    var duplicatViewController  : TapeDelayViewController!
    var iaaWrapper : IAAWrapper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let backgroundImage = backgroundImageView.image {
            backgroundImageView.image = backgroundImage.resizableImageWithCapInsets(UIEdgeInsetsZero, resizingMode: UIImageResizingMode.Tile);
        }
        
        if let auContainerBevelBackgroundImage = auContainerBevelView.image {
            auContainerBevelView.image = auContainerBevelBackgroundImage.resizableImageWithCapInsets(UIEdgeInsetsMake(8, 8, 8, 8), resizingMode: UIImageResizingMode.Stretch);
        }
        
        iaaControlContainerView.hidden = true
        iaaControlHostIconImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onHostImageTapped)))
        
        embedPlugInView()
        
        iaaWrapper = IAAWrapper()
        iaaWrapper.createAndPublish()
        iaaWrapper.delegate = self
        
        let au = iaaWrapper.getAudioUnit()
        duplicatViewController.audioUnit = au
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

    func onHostImageTapped(gesture: UITapGestureRecognizer) {
        if let iaaWrapperUnwrapped = iaaWrapper {
            iaaWrapperUnwrapped.goToHost()
        }
    }
    
    @IBAction func onRewindTapped(sender: AnyObject) {
    }
    
    @IBAction func onPlayTapped(sender: AnyObject) {
    }
    
    @IBAction func onRecordTapped(sender: AnyObject) {
    }
    
}

extension ViewController : IAAWrapperDelegate {
    func iaaWrapperDidConnect(iaaWrapper: IAAWrapper) {
        iaaControlContainerView.hidden = false
    }
    
    func iaaWrapperDidDisconnect(iaaWrapper: IAAWrapper) {
        iaaControlContainerView.hidden = true
    }
    
    func iaaWrapperDidReceiveHostIcon(iaaWrapper: IAAWrapper, hostIcon: UIImage) {
        iaaControlHostIconImageView.image = hostIcon
    }
}


