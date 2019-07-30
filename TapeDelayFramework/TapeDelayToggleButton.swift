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
        self.addTarget(self, action: #selector(TapeDelayToggleButton.didTouchUpInside), for: .touchUpInside)
    }
    
    @objc
    func didTouchUpInside() {
        if (!self.isSelected) {
            self.isSelected = true
        } else {
            self.isSelected = false
        }
        
        self.sendActions(for: .valueChanged)
    }
}
