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

    @IBOutlet var auContainerView           : UIView?
    @IBOutlet var backgroundImageView       : UIImageView?
    @IBOutlet var auContainerBevelView      : UIImageView?
    
    @IBOutlet var userGuideView             : UIImageView?
    @IBOutlet var userGuideZoomConstraint   : NSLayoutConstraint?
    
    @IBOutlet var transportView : IAATransportView?
    
    var duplicatViewController  : TapeDelayViewController?
    
    var userGuideZoomed: Bool = false {
        didSet {
            if userGuideZoomed != oldValue {
                userGuideZoomConstraint?.active = userGuideZoomed
                view.setNeedsUpdateConstraints()
                
                UIView.animateWithDuration(0.2, animations: { 
                    self.view.layoutIfNeeded()
                })

            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure resizable images in UI
        if let backgroundImageView = backgroundImageView, backgroundImage = backgroundImageView.image {
            backgroundImageView.image = backgroundImage.resizableImageWithCapInsets(UIEdgeInsetsZero, resizingMode: UIImageResizingMode.Tile);
        }
        
        if let auContainerBevelView = auContainerBevelView, auContainerBevelBackgroundImage = auContainerBevelView.image {
            auContainerBevelView.image = auContainerBevelBackgroundImage.resizableImageWithCapInsets(UIEdgeInsetsMake(8, 8, 8, 8), resizingMode: UIImageResizingMode.Stretch);
        }

        // Embed the effect's plugin view
        embedPlugInView()

        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if let iaaWrapper = appDelegate.iaaWrapper {
     
            // Create the iaaWrapper and publish it for IAA
            iaaWrapper.delegate = self
            iaaWrapper.createAndPublish()
            
            if let transportView = transportView {
                
                // Link transport view to the iaaWrapper
                transportView.delegate = iaaWrapper
                
            }
        }
        
        // Add gesture for taps on user guide
        userGuideView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onUserGuideTapped)))
        userGuideView?.userInteractionEnabled = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func onUserGuideTapped(uigr: UIGestureRecognizer) {
        // Toggle userguide zoom
        userGuideZoomed = !userGuideZoomed
    }
    
    
    /// Called from `viewDidLoad(_:)` to embed the plug-in's view into the app's view.
    func embedPlugInView() {
        /*
        Locate the app extension's bundle, in the app bundle's PlugIns
        subdirectory. Load its MainInterface storyboard, and obtain the
        `TapeDelayViewController` from that.
        */
        guard let builtInPlugInsURL = NSBundle.mainBundle().builtInPlugInsURL,
            pluginURL = builtInPlugInsURL.URLByAppendingPathComponent("DuplicatAppex.appex"),
            appExtensionBundle = NSBundle(URL: pluginURL)   else {
                // Cannot load storyboard
                return
        }
        
        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)

        // Present the view controller's view.
        guard let duplicatViewController = storyboard.instantiateInitialViewController() as? TapeDelayViewController,
            view = duplicatViewController.view,
            auContainerView = auContainerView else {

                return
        }
        
        addChildViewController(duplicatViewController)
        view.frame = auContainerView.bounds
        view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        auContainerView.addSubview(view)
        duplicatViewController.didMoveToParentViewController(self)
        
        self.duplicatViewController = duplicatViewController
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent;
    }

}

extension ViewController : IAAWrapperDelegate {
    func audioUnitDidConnect(iaaWrapper: IAAWrapper, audioUnit : AUAudioUnit?) {
        if let duplicatViewController = duplicatViewController, audioUnit = audioUnit  {
            duplicatViewController.tapeDelayAudioUnit = (audioUnit as! TapeDelay)
        }
    }
}

