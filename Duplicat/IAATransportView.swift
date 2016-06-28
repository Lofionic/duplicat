//
//  TransportView.swift
//  Duplicat
//
//  Created by Chris Rivers on 23/06/2016.
//  Copyright © 2016 Lofionic. All rights reserved.
//

import UIKit

public protocol IAATransportViewDelegate {
    
    func isHostPlaying() -> Bool
    func isHostRecording() -> Bool
    func isHostConnected() -> Bool
    func getHostIcon() -> UIImage?

    func canPlay() -> Bool
    func canRewind() -> Bool
    func canRecord() -> Bool
    
    
    func goToHost()
    func hostRewind()
    func hostPlay()
    func hostRecord()
}

public class IAATransportView: UIView {
    
    var delegate : IAATransportViewDelegate? {
        didSet {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(iaaTransportStateDidChangeNotification), name: kIAATransportStateChangedNotification, object: delegate as! AnyObject?)
        }
    }
    
    @IBOutlet var hostIcon      : UIImageView!
    @IBOutlet var rewindButton  : UIButton!
    @IBOutlet var playButton    : UIButton!
    @IBOutlet var recordButton  : UIButton!
    
    var appIsForeground : Bool?
    
    public override func awakeFromNib() {

        hidden = true // Assume hidden by default
        
        let appstate = UIApplication.sharedApplication().applicationState
        appIsForeground = appstate != .Background
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(appHasGoneInBackground),
                                                         name: UIApplicationDidEnterBackgroundNotification,
                                                         object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(appHasGoneForeground),
                                                         name: UIApplicationWillEnterForegroundNotification,
                                                         object: nil)
        
        hostIcon.userInteractionEnabled = true
        hostIcon.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onHostImageTapped)))
    
    }
 
    @objc
    func appHasGoneInBackground(note : NSNotification) {
        appIsForeground = false
    }
    
    @objc
    func appHasGoneForeground(note : NSNotification) {
        appIsForeground = true
        updateTransportControls()
    }
    
    func iaaTransportStateDidChangeNotification(note : NSNotification) {
        updateTransportControls()
    }
    
    func updateTransportControls() {
        if let delegate = delegate {
            if (delegate.isHostConnected()) {
                self.hidden = false;
            } else {
                self.hidden = true;
            }
            
            self.playButton.selected = delegate.isHostPlaying()
            self.recordButton.selected = delegate.isHostRecording()
            
//            self.rewindButton.enabled = delegate.canRewind()
//            self.playButton.enabled = delegate.canPlay()
//            self.recordButton.enabled = delegate.canRecord()
            
            self.hostIcon.image = delegate.getHostIcon()
        }
    }
    
    @IBAction func onRewindTapped(sender: AnyObject) {
        if let delegateUnwrapped = delegate {
            delegateUnwrapped.hostRewind()
        }
    }
    
    @IBAction func onPlayTapped(sender: AnyObject) {
        if let delegateUnwrapped = delegate {
            delegateUnwrapped.hostPlay()
        }
    }
    
    @IBAction func onRecordTapped(sender: AnyObject) {
        if let delegateUnwrapped = delegate {
            delegateUnwrapped.hostRecord()
        }
    }
    
    func onHostImageTapped(uigr : UIGestureRecognizer) {
        if let delegateUnwrapped = delegate {
            delegateUnwrapped.goToHost()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

}