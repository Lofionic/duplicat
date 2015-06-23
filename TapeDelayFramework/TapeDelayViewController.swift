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

    @IBOutlet weak var delayTimeSlider : UISlider!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
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
    
    var delayTimeParameter:         AUParameter?
    var delayLevelParameter:        AUParameter?
    var feedbackParameter:          AUParameter?
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
        
        guard let paramTree = audioUnit?.parameterTree else { return }
        
        delayTimeParameter = paramTree.valueForKey("delayTime") as? AUParameter
        delayLevelParameter = paramTree.valueForKey("delayLevel") as? AUParameter
        feedbackParameter = paramTree.valueForKey("feedback") as? AUParameter
        
        self.delayTimeSlider.minimumValue = delayTimeParameter!.minValue
        self.delayTimeSlider.maximumValue = delayTimeParameter!.maxValue
        
        parameterObserverToken = paramTree.tokenByAddingParameterObserver { address, value in
            dispatch_async(dispatch_get_main_queue()) {
                if address == self.delayTimeParameter!.address {
                }
                else if address == self.delayLevelParameter!.address {

                }
            }
        }
        
        delayTimeSlider.value = delayTimeParameter!.value
    }
    
    @IBAction func delayTimeSliderValueChanged(sender: AnyObject) {
        NSLog("%.2f", self.delayTimeSlider.value)
        delayTimeParameter?.setValue(self.delayTimeSlider.value, originator: parameterObserverToken!)
    }
}