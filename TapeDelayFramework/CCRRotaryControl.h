//
//  Created by Chris Rivers on 22/02/2014.
//  Copyright (c) 2014 Lofionic. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCRRotaryControl : UIControl

@property float value;
@property int exponent;
@property int sensitivity;
@property (assign) float defaultValue;
@property bool enableDefaultValue;
@property (nonatomic, strong) UIImage *spriteSheet;
@property (nonatomic, strong) UIImage *backgroundImage;
@property CGSize spriteSize;

@property bool changeByRotating;

@end
