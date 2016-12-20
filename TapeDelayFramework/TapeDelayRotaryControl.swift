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

    let screenScale = UIScreen.main.scale
    
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
    let spriteSize = CGSize(width: 80 * UIScreen.main.scale, height: 80 * UIScreen.main.scale)

    override func awakeFromNib() {
        self.initialize()
    }
    
    func initialize() {
        // Initialize properties
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = true
        
        // Set up the double tap gesture
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapGesture)
    }
    
    func doubleTap(gesture: UIGestureRecognizer) {
        if (gesture.state == UIGestureRecognizerState.ended && self.doubleTapForDefault) {
            value = defaultValue
        }
    }
    
    override func layoutSubviews() {
        let originalCenter = center
        let size = min(frame.size.width, frame.size.height)
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        center = originalCenter
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Begin touch tracking
        let firstTouch = touches.first
        previousTrackingLocation = firstTouch?.location(in: self).y
        trackingTouches = true
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (trackingTouches) {
            if let firstTouch = touches.first {
                let firstTouchLocation = firstTouch.location(in: self).y
                let delta = Float(((firstTouchLocation - previousTrackingLocation!) * 3.0) / 500.0)
                
                value -= delta
                
                previousTrackingLocation = firstTouchLocation
            }
            
            if (value > 1.0) {
                value = 1.0
            } else if (value < 0) {
                value = 0
            }

            sendActions(for: .valueChanged)
            
            //sendActions(for: UIControlEvents.valueChanged)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackingTouches = false
        resignFirstResponder()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    override func draw(_ rect: CGRect) {
        if let spriteSheetUnwrapped = spriteSheet {
            let ctx = UIGraphicsGetCurrentContext()
            ctx!.saveGState()
            ctx!.scaleBy(x: 1.0, y: -1.0)
            
            let spriteCount : Int = Int((spriteSheetUnwrapped.size.height / spriteSize.height) * UIScreen.main.scale) - 1
            let frame : Int = Int(value * Float(spriteCount))
            let sourceRect = CGRect(x: 0, y: CGFloat(frame * Int(self.spriteSize.height)), width: self.spriteSize.width, height: self.spriteSize.height)
            if let drawImage = spriteSheetUnwrapped.cgImage!.cropping(to: sourceRect) {
                ctx!.draw(drawImage, in: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: -self.bounds.size.height))
            }
            
            ctx!.restoreGState()
        }
    }
}
