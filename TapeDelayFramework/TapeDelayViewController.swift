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
    /*!	@brief	Create an instance of an extension's AUAudioUnit.
    	@discussion
     This method should create and return an instance of its audio unit.
     
     This method will be called only once per instance of the factory.
     
     Note that in non-ARC code, "create" methods return unretained objects (unlike "create" 
     C functions); the implementor should return an object with reference count 1 but
     autoreleased.
     */
    @IBOutlet weak var backgroundImageView              : UIImageView!
  
    @IBOutlet weak var tapeSpeedControl     : TapeDelayRotaryControl!
    @IBOutlet weak var mixControl           : TapeDelayRotaryControl!
    @IBOutlet weak var feedbackControl      : TapeDelayRotaryControl!
    @IBOutlet weak var tapeEffectControl    : TapeDelayRotaryControl!

    @IBOutlet public weak var shortDelayButton     : TapeDelayToggleButton!
    @IBOutlet public weak var mediumDelayButton    : TapeDelayToggleButton!
    @IBOutlet public weak var longDelayButton      : TapeDelayToggleButton!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let backgroundImage = UIImage(named:"background")?.resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: UIImageResizingMode.tile)
        backgroundImageView.image = backgroundImage
        
        if (tapeDelayAudioUnit != nil) {
            connectViewWithAU(audioUnit: tapeDelayAudioUnit)
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        guard
            let mixParameter = mixParameter,
            let feedbackParameter = feedbackParameter,
            let tapeSpeedParameter = tapeSpeedParameter,
            let tapeEffectParameter = tapeEffectParameter else {
                return
        }
        
        updateMixControl(value: mixParameter.value)
        updateFeedbackControl(value: feedbackParameter.value)
        updateTapeSpeedControl(value: tapeSpeedParameter.value)
        updateTapeEffectControl(value: tapeEffectParameter.value)
        updateDelayButtons()
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
            DispatchQueue.main.async {
                if self.isViewLoaded {
                    if let audioUnitUnwrapped = self.tapeDelayAudioUnit {
                        self.connectViewWithAU(audioUnit: audioUnitUnwrapped)
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
    
    public func createAudioUnit(with desc: AudioComponentDescription) throws -> AUAudioUnit {
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
        
        mixParameter = paramTree.value(forKey: "mix") as? AUParameter
        feedbackParameter = paramTree.value(forKey: "feedback") as? AUParameter
        tapeSpeedParameter = paramTree.value(forKey: "tapeSpeed") as? AUParameter
        tapeEffectParameter = paramTree.value(forKey: "tapeEffect") as? AUParameter
        
        shortDelayParameter = paramTree.value(forKey: "shortDelay") as? AUParameter
        mediumDelayParameter = paramTree.value(forKey: "mediumDelay") as? AUParameter
        longDelayParameter = paramTree.value(forKey: "longDelay") as? AUParameter
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: {
            [weak self] address, value in
            
            guard let strongSelf = self else { return }
            
            DispatchQueue.main.async {
                if address == strongSelf.tapeSpeedParameter!.address {
                    strongSelf.updateTapeSpeedControl(value: value);
                } else if address == strongSelf.mixParameter!.address {
                    strongSelf.updateMixControl(value: value)
                } else if address == strongSelf.feedbackParameter!.address {
                    strongSelf.updateFeedbackControl(value: value)
                } else if address == strongSelf.tapeEffectParameter!.address {
                    strongSelf.updateTapeEffectControl(value: value);
                } else if address == strongSelf.shortDelayParameter!.address ||
                    address == strongSelf.mediumDelayParameter!.address ||
                    address == strongSelf.longDelayParameter!.address {
                        strongSelf.updateDelayButtons();
                }
            }
        })
 
        updateTapeSpeedControl(value: tapeSpeedParameter!.value);
        updateMixControl(value: mixParameter!.value);
        updateFeedbackControl(value: feedbackParameter!.value);
        updateTapeEffectControl(value: tapeEffectParameter!.value);
        updateDelayButtons();
    }
        
    private func updateMixControl(value: AUValue) {
        guard let mixParameter = mixParameter else { return }
        mixControl.value = mixParameter.value;
    }
    
    private func updateFeedbackControl(value: AUValue) {
        if (tapeDelayAudioUnit != nil) {
            feedbackControl.value = value
        }
    }
    
    private func updateTapeSpeedControl(value: AUValue) {
        if (tapeDelayAudioUnit != nil) {
            tapeSpeedControl.value = value
        }
    }

    private func updateTapeEffectControl(value: AUValue) {
        if (tapeDelayAudioUnit != nil) {
            tapeEffectControl.value = value
        }
    }
    
    private func updateDelayButtons() {
        if (tapeDelayAudioUnit != nil) {
            shortDelayButton.isSelected   = shortDelayParameter!.value == 1.0
            mediumDelayButton.isSelected  = mediumDelayParameter!.value == 1.0
            longDelayButton.isSelected    = longDelayParameter!.value == 1.0
        }
    }
    
    @IBAction func tapeSpeedControlValueChanged(sender: AnyObject) {
        tapeSpeedParameter?.value = self.tapeSpeedControl.value;
    }
    
    @IBAction func mixControlValueChanged(sender: AnyObject) {
        mixParameter?.setValue(self.mixControl.value, originator: parameterObserverToken)
    }
    
    @IBAction func feedbackControlValueChanged(sender: AnyObject) {
        feedbackParameter?.setValue(self.feedbackControl.value, originator: parameterObserverToken)
    }
    
    @IBAction func tapeEffectControlValueChanged(sender: AnyObject) {
        tapeEffectParameter?.setValue(self.tapeEffectControl.value, originator: parameterObserverToken)
    }
    
    @IBAction func delayToggleButtonValueChanged(sender: AnyObject) {
        guard let tapeDelayToggleButton = sender as? TapeDelayToggleButton else { return }
        let auValue = (tapeDelayToggleButton.isSelected ? 1.0 : 0.0) as AUValue
        if tapeDelayToggleButton == shortDelayButton {
            shortDelayParameter?.setValue(auValue, originator: parameterObserverToken)
        } else if tapeDelayToggleButton == mediumDelayButton {
            mediumDelayParameter?.setValue(auValue, originator: parameterObserverToken)
        } else if tapeDelayToggleButton == longDelayButton {
            longDelayParameter?.setValue(auValue, originator: parameterObserverToken)
        }
    }
}
