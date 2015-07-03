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
    @IBOutlet weak var topPanelBackgroundImageView      : UIImageView!
    @IBOutlet weak var midPanelBackgroundImageView      : UIImageView!
    
    @IBOutlet weak var tapeSpeedSlider  : UISlider!
    @IBOutlet weak var mixSlider        : UISlider!
    @IBOutlet weak var feedbackSlider   : UISlider!
    @IBOutlet weak var tapeEffectSlider : UISlider!
    
    @IBOutlet weak var shortDelayButton     : TapeDelayToggleButton!
    @IBOutlet weak var mediumDelayButton    : TapeDelayToggleButton!
    @IBOutlet weak var longDelayButton      : TapeDelayToggleButton!
  
    @IBOutlet weak var tapeDelayView : TapeDelayView!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let backgroundImage = UIImage(named:"background")?.resizableImageWithCapInsets(UIEdgeInsetsZero, resizingMode: UIImageResizingMode.Tile)
        backgroundImageView.image = backgroundImage
        
        connectViewWithAU()
    }
    
    public var audioUnit: TapeDelay? {
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
                    self.connectViewWithAU()
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
        audioUnit = try TapeDelay(componentDescription: desc, options: [])
        
        return audioUnit!
    }
    
    /*
    We can't assume anything about whether the view or the AU is created first.
    This gets called when either is being created and the other has already
    been created.
    */
    func connectViewWithAU() {
        return
        
        guard let paramTree = audioUnit?.parameterTree else { return }
        
        tapeSpeedParameter = paramTree.valueForKey("tapeSpeed") as? AUParameter
        mixParameter = paramTree.valueForKey("mix") as? AUParameter
        feedbackParameter = paramTree.valueForKey("feedback") as? AUParameter
        tapeEffectParameter = paramTree.valueForKey("tapeEffect") as? AUParameter
        
        shortDelayParameter = paramTree.valueForKey("shortDelay") as? AUParameter
        mediumDelayParameter = paramTree.valueForKey("mediumDelay") as? AUParameter
        longDelayParameter = paramTree.valueForKey("longDelay") as? AUParameter
        
        parameterObserverToken = paramTree.tokenByAddingParameterObserver { address, value in
            dispatch_async(dispatch_get_main_queue()) {
                if address == self.tapeSpeedParameter!.address {
                    self.tapeSpeedSlider.value = value
                } else if address == self.mixParameter!.address {
                    self.mixSlider.value = value
                } else if address == self.feedbackParameter!.address {
                    self.feedbackSlider.value = value
                } else if address == self.tapeEffectParameter!.address {
                    self.tapeEffectSlider.value = value
                }
            }
        }
        
        tapeSpeedSlider.value   = tapeSpeedParameter!.value
        mixSlider.value         = mixParameter!.value
        feedbackSlider.value    = feedbackParameter!.value
        tapeEffectSlider.value  = tapeEffectParameter!.value
    }
    
    @IBAction func tapeSpeedSliderValueChanged(sender: AnyObject) {
        tapeSpeedParameter?.setValue(self.tapeSpeedSlider.value, originator: parameterObserverToken!)
    }
    
    @IBAction func mixSliderValueChanged(sender: AnyObject) {
        mixParameter?.setValue(self.mixSlider.value, originator: parameterObserverToken!)
    }
    
    @IBAction func feedbackSliderValueChanged(sender: AnyObject) {
        feedbackParameter?.setValue(self.feedbackSlider.value, originator: parameterObserverToken!)
    }
    
    @IBAction func tapeEffectSliderValueChanged(sender: AnyObject) {
        tapeEffectParameter?.setValue(self.tapeEffectSlider.value, originator: parameterObserverToken!)
    }
    
    @IBAction func delayToggleButtonValueChanged(sender: AnyObject) {
        let tapeDelayToggleButton = sender as! TapeDelayToggleButton
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