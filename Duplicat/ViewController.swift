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
                userGuideZoomConstraint?.isActive = userGuideZoomed
                view.setNeedsUpdateConstraints()
                
                UIView.animate(withDuration: 0.2, animations: { 
                    self.view.layoutIfNeeded()
                })

            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure resizable images in UI
        if let backgroundImageView = backgroundImageView, let backgroundImage = backgroundImageView.image {
            backgroundImageView.image = backgroundImage.resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: UIImageResizingMode.tile);
        }
        
        if let auContainerBevelView = auContainerBevelView, let auContainerBevelBackgroundImage = auContainerBevelView.image {
            auContainerBevelView.image = auContainerBevelBackgroundImage.resizableImage(withCapInsets: UIEdgeInsetsMake(8, 8, 8, 8), resizingMode: UIImageResizingMode.stretch);
        }

        // Embed the effect's plugin view
        embedPlugInView()

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
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
        userGuideView?.isUserInteractionEnabled = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func onUserGuideTapped(_ uigr: UIGestureRecognizer) {
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
        guard let builtInPlugInsURL = Bundle.main.builtInPlugInsURL else {
            return
        }
        let pluginURL = builtInPlugInsURL.appendingPathComponent("DuplicatAppex.appex")
        guard let appExtensionBundle = Bundle(url: pluginURL) else {
            return
        }
        
        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)

        // Present the view controller's view.
        guard let duplicatViewController = storyboard.instantiateInitialViewController() as? TapeDelayViewController,
            let view = duplicatViewController.view,
            let auContainerView = auContainerView else {

                return
        }
        
        addChildViewController(duplicatViewController)
        view.frame = auContainerView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        auContainerView.addSubview(view)
        duplicatViewController.didMove(toParentViewController: self)
        
        self.duplicatViewController = duplicatViewController
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

}

extension ViewController : IAAWrapperDelegate {
    func audioUnitDidConnect(_ iaaWrapper: IAAWrapper, audioUnit : AUAudioUnit?) {
        if let duplicatViewController = duplicatViewController, let audioUnit = audioUnit  {
            duplicatViewController.tapeDelayAudioUnit = (audioUnit as! TapeDelay)
        }
    }
}

