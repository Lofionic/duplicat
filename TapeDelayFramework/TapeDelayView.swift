//
//  TapeDelayView.swift
//  TapeDelay
//
//  Created by Chris on 26/06/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//
import Foundation
import UIKit

class TapeDelayView : UIView {
  
    var tapeLayer = CAShapeLayer()
    var markerLayer = CAShapeLayer()

    var top : CGFloat = 0
    var left : CGFloat = 0
    var drawWidth : CGFloat = 0
    var drawHeight : CGFloat = 0
    
    override func layoutSublayersOfLayer(layer: CALayer) {
        createLayers()
    }
    
    func createLayers() {
        createTapeLayer()
        createMarker()
        animateMarker()
    }
    
    func createTapeLayer() {
        
        let view = self
        
        drawHeight = (view.bounds.height * 0.6)
        
        let centerY = view.bounds.height / 2.0
        top = centerY - drawHeight / 2.0
        
        drawWidth = drawHeight * 2
        
        let centerX = view.bounds.width / 2.0
        left = centerX - (drawWidth / 2.0)
        
        let bezierPath = CGPathCreateMutable()
        CGPathMoveToPoint(bezierPath, nil, left + drawWidth * 0.3, top + drawHeight)
        CGPathAddLineToPoint(bezierPath, nil, left + drawWidth * 0.7, top + drawHeight)
        
        CGPathAddCurveToPoint(bezierPath, nil,
            left + drawWidth, top + drawHeight,
            left + drawWidth, top,
            left + drawWidth * 0.7, top)
        
        CGPathAddLineToPoint(bezierPath, nil,
            left + drawWidth * 0.3, top)
        
        CGPathAddCurveToPoint(bezierPath, nil,
            left, top,
            left, top + drawHeight,
            left + drawWidth * 0.3, top + drawHeight)
        
        CGPathCloseSubpath(bezierPath)
    
        tapeLayer.strokeColor = UIColor.blackColor().CGColor
        tapeLayer.fillColor = UIColor.clearColor().CGColor
        tapeLayer.lineWidth = 3
        
        tapeLayer.path = bezierPath
        
        tapeLayer.frame = view.bounds;
        view.layer.addSublayer(tapeLayer)
    }
    
    func createMarker() {
        
        let markerRect = CGRect(x: 0, y: 0, width: 8, height: 8)
        
        let markerPath = CGPathCreateMutable()
        CGPathAddEllipseInRect(markerPath, nil, markerRect)
        
        markerLayer.strokeColor = UIColor.clearColor().CGColor
        markerLayer.fillColor = UIColor.redColor().CGColor
        
        markerLayer.path = markerPath
        
        markerLayer.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        self.layer.addSublayer(markerLayer)
    }
    
    func animateMarker() {
        
        markerLayer.removeAllAnimations()
        
        let moveAlongPath = CAKeyframeAnimation(keyPath: "position")
        let animationPath = CGPathCreateMutableCopy(tapeLayer.path)
        
        moveAlongPath.path = animationPath
        moveAlongPath.duration = 2.0
        
        moveAlongPath.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        moveAlongPath.calculationMode = kCAAnimationPaced
        
        moveAlongPath.delegate = self
        moveAlongPath.repeatCount = Float.infinity
        
        markerLayer.addAnimation(moveAlongPath, forKey: "moveAlongPath")
    }
}
