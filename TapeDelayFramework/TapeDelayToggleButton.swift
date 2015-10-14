//
//  TapeDelayToggleButton.swift
//  TapeDelay
//
//  Created by Chris on 30/06/2015.
//  Copyright © 2015 Lofionic. All rights reserved.
//
import UIKit
import Foundation

public class TapeDelayToggleButton : UIButton {
    
    public override func awakeFromNib() {
        self.addTarget(self, action: "didTouchUpInside", forControlEvents: .TouchUpInside)
    }
    
    func didTouchUpInside() {
        if (!self.selected) {
            self.selected = true
        } else {
            self.selected = false
        }
        
        self.sendActionsForControlEvents(.ValueChanged)
    }
    
}