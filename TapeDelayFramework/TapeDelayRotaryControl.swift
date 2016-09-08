//
//  TapeDelayRotaryControl.swift
//  TapeDelay
//
//  Created by Chris on 04/07/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//
import UIKit
import Foundation
import QuartzCore

class TapeDelayRotaryControl : UIControl {

    let screenScale = UIScreen.mainScreen().scale
    
    var value : Float           = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var defaultValue : Float    = 0.0
    var doubleTapForDefault : Bool   = false
    var previousTrackingLocation : CGFloat?
    var trackingTouches : Bool = false
    
    let spriteSheet = UIImage(named:"knob")
    let spriteSize = CGSizeMake(80 * UIScreen.mainScreen().scale, 80 * UIScreen.mainScreen().scale)
    
    override func awakeFromNib() {
        self.initialize()
    }
    
    func initialize() {
        // Initialize properties
        self.backgroundColor = UIColor.clearColor()
        self.userInteractionEnabled = true
        
        // Set up the double tap gesture
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapGesture)
    }
    
    func doubleTap(gesture: UIGestureRecognizer) {
        if (gesture.state == UIGestureRecognizerState.Ended && self.doubleTapForDefault) {
            value = defaultValue
        }
    }
    
    override func layoutSubviews() {
        let originalCenter = center
        let size = min(frame.size.width, frame.size.height)
        frame = CGRectMake(0, 0, size, size)
        center = originalCenter
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        // Begin touch tracking
        let firstTouch = touches.first
        previousTrackingLocation = firstTouch?.locationInView(self).y
        trackingTouches = true
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if (trackingTouches) {
            if let firstTouch = touches.first {
                let firstTouchLocation = firstTouch.locationInView(self).y
                let delta = Float(((firstTouchLocation - previousTrackingLocation!) * 3.0) / 500.0)
                
                value -= delta
                
                previousTrackingLocation = firstTouchLocation
            }
            
            if (value > 1.0) {
                value = 1.0
            } else if (value < 0) {
                value = 0
            }

            sendActionsForControlEvents(UIControlEvents.ValueChanged)
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        trackingTouches = false
        resignFirstResponder()
    }
    
    override func touchesCancelled(touches: Set<UITouch>, withEvent event: UIEvent?) {
        touchesEnded(touches, withEvent: event)
    }
    
    override func drawRect(rect: CGRect) {
        if let spriteSheetUnwrapped = spriteSheet {
            let ctx = UIGraphicsGetCurrentContext()
            CGContextSaveGState(ctx!)
            CGContextScaleCTM(ctx!, 1.0, -1.0)
            
            let spriteCount : Int = Int((spriteSheetUnwrapped.size.height / spriteSize.height) * UIScreen.mainScreen().scale) - 1
            let frame : Int = Int(value * Float(spriteCount))
            let sourceRect = CGRectMake(0, CGFloat(frame * Int(self.spriteSize.height)), self.spriteSize.width, self.spriteSize.height)
            let drawImage = CGImageCreateWithImageInRect(spriteSheetUnwrapped.CGImage!, sourceRect)
            
            CGContextDrawImage(ctx!, CGRectMake(0, 0, self.bounds.size.width, -self.bounds.size.height), drawImage!)
            CGContextRestoreGState(ctx!)
        }
    }
}
