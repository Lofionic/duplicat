//
//  TapeDelayViewController.swift
//  TapeDelay
//
//  Created by Chris on 21/06/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//
import UIKit
import CoreAudioKit

public class TapeDelayViewController: AUViewController, AUAudioUnitFactory {

    @IBOutlet weak var backgroundImageView              : UIImageView!
  
    @IBOutlet weak var tapeSpeedControl     : TapeDelayRotaryControl!
    @IBOutlet weak var mixControl           : TapeDelayRotaryControl!
    @IBOutlet weak var feedbackControl      : TapeDelayRotaryControl!
    @IBOutlet weak var tapeEffectControl    : TapeDelayRotaryControl!
    
    @IBOutlet weak var mixSlider    : UISlider!
    
    @IBOutlet public weak var shortDelayButton     : TapeDelayToggleButton!
    @IBOutlet public weak var mediumDelayButton    : TapeDelayToggleButton!
    @IBOutlet public weak var longDelayButton      : TapeDelayToggleButton!
  
    @IBOutlet weak var tapeDelayView : TapeDelayView!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let backgroundImage = UIImage(named:"background")?.resizableImageWithCapInsets(UIEdgeInsetsZero, resizingMode: UIImageResizingMode.Tile)
        backgroundImageView.image = backgroundImage
        
        if (tapeDelayAudioUnit != nil) {
            connectViewWithAU(tapeDelayAudioUnit)
        }
    }
    
    public var tapeDelayAudioUnit: TapeDelay? {
        didSet {
            /*
            We may be on a dispatch worker queue processing an XPC request at
            this time, and quite possibly the main queue is busy creating the
            view. To be thread-safe, dispatch onto the main queue.
            
            It's also possible that we are already on the main queue, so to
            protect against deadlock in that case, dispatch asynchronously.
            */
            dispatch_async(dispatch_get_main_queue()) {
                if self.isViewLoaded() {
                    if let audioUnitUnwrapped = self.tapeDelayAudioUnit {
                        self.connectViewWithAU(audioUnitUnwrapped)
                    }
                }
            }
        }
    }
    
    var tapeSpeedParameter:         AUParameter?
    var mixParameter:               AUParameter?
    var feedbackParameter:          AUParameter?
    var tapeEffectParameter:        AUParameter?
    
    var shortDelayParameter:        AUParameter?
    var mediumDelayParameter:       AUParameter?
    var longDelayParameter:         AUParameter?
    
    var parameterObserverToken:     AUParameterObserverToken?
    
    public func createAudioUnitWithComponentDescription(desc: AudioComponentDescription) throws -> AUAudioUnit {
        tapeDelayAudioUnit = try TapeDelay(componentDescription: desc, options: [])
        return tapeDelayAudioUnit!
    }
    
    /*
    We can't assume anything about whether the view or the AU is created first.
    This gets called when either is being created and the other has already
    been created.
    */
    func connectViewWithAU(audioUnit: AUAudioUnit?) {
        
        guard let paramTree = audioUnit?.parameterTree else { return }
        
        tapeSpeedParameter = paramTree.valueForKey("tapeSpeed") as? AUParameter
        mixParameter = paramTree.valueForKey(kDuplicatParam_Mix) as? AUParameter
        feedbackParameter = paramTree.valueForKey("feedback") as? AUParameter
        tapeEffectParameter = paramTree.valueForKey("tapeEffect") as? AUParameter
        
        shortDelayParameter = paramTree.valueForKey("shortDelay") as? AUParameter
        mediumDelayParameter = paramTree.valueForKey("mediumDelay") as? AUParameter
        longDelayParameter = paramTree.valueForKey("longDelay") as? AUParameter
        
        weak var weakSelf = self;
        parameterObserverToken = paramTree.tokenByAddingParameterObserver { address, value in
            dispatch_async(dispatch_get_main_queue()) {
                if address == self.tapeSpeedParameter!.address {
                    weakSelf!.updateTapeSpeedControl();
                } else if address == self.mixParameter!.address {
                    weakSelf!.updateMixControl()
                } else if address == self.feedbackParameter!.address {
                    weakSelf!.updateFeedbackControl()
                } else if address == self.tapeEffectParameter!.address {
                    weakSelf!.updateTapeSpeedControl();
                } else if address == self.shortDelayParameter!.address ||
                    address == self.mediumDelayParameter!.address ||
                    address == self.longDelayParameter!.address {
                        weakSelf!.updateDelayButtons();
                }
            }
        }
        
        updateTapeSpeedControl();
        updateMixControl();
        updateFeedbackControl();
        updateTapeEffectControl();
        
        updateDelayButtons();
    }
        
    private func updateMixControl() {
        if (tapeDelayAudioUnit != nil) {
            mixControl.value = mixParameter!.value
        }
    }
    
    private func updateFeedbackControl() {
        if (tapeDelayAudioUnit != nil) {
            feedbackControl.value    = feedbackParameter!.value
        }
    }
    
    private func updateTapeSpeedControl() {
        if (tapeDelayAudioUnit != nil) {
            tapeSpeedControl.value   = tapeSpeedParameter!.value
        }
    }

    private func updateTapeEffectControl() {
        if (tapeDelayAudioUnit != nil) {
            tapeEffectControl.value  = tapeEffectParameter!.value
        }
    }
    
    private func updateDelayButtons() {
        
        if (tapeDelayAudioUnit != nil) {
            shortDelayButton.selected   = shortDelayParameter!.value == 1.0
            mediumDelayButton.selected  = mediumDelayParameter!.value == 1.0
            longDelayButton.selected    = longDelayParameter!.value == 1.0
        }
    }
    
    @IBAction func tapeSpeedControlValueChanged(sender: AnyObject) {
        if (tapeDelayAudioUnit != nil) {
            tapeSpeedParameter?.setValue(self.tapeSpeedControl.value, originator: parameterObserverToken!)
        }
    }
    
    @IBAction func mixControlValueChanged(sender: AnyObject) {
        if (tapeDelayAudioUnit != nil) {
            mixParameter?.setValue(self.mixControl.value, originator: parameterObserverToken!)
        }
    }
    
    @IBAction func feedbackControlValueChanged(sender: AnyObject) {
        if (tapeDelayAudioUnit != nil) {
            feedbackParameter?.setValue(self.feedbackControl.value, originator: parameterObserverToken!)
        }
    }
    
    @IBAction func tapeEffectControlValueChanged(sender: AnyObject) {
        if (tapeDelayAudioUnit != nil) {
            tapeEffectParameter?.setValue(self.tapeEffectControl.value, originator: parameterObserverToken!)
        }
    }
    
    @IBAction func delayToggleButtonValueChanged(sender: AnyObject) {
        let tapeDelayToggleButton = sender as! TapeDelayToggleButton
        
        if (tapeDelayAudioUnit != nil) {
            let auValue = (tapeDelayToggleButton.selected ? 1.0 : 0.0) as AUValue
            if tapeDelayToggleButton == shortDelayButton {
                shortDelayParameter?.setValue(auValue, originator: parameterObserverToken!)
            } else if tapeDelayToggleButton == mediumDelayButton {
                mediumDelayParameter?.setValue(auValue, originator: parameterObserverToken!)
            } else if tapeDelayToggleButton == longDelayButton {
                longDelayParameter?.setValue(auValue, originator: parameterObserverToken!)
            }
        }
    }
}