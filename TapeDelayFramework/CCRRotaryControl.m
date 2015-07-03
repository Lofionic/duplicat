//
//  Created by Chris Rivers on 22/02/2014.
//  Copyright (c) 2014 Lofionic. All rights reserved.
//
#import "CCRRotaryControl.h"
#import <QuartzCore/QuartzCore.h>

@implementation CCRRotaryControl {
    // Records the previous tracking location
    CGPoint previousTrackingTouchLocation;
    
    // is control tracking
    bool tracking;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self initialize];
    }
    return self;
}

-(void)awakeFromNib {
    [self initialize];
}

-(void)initialize {
    
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    
    // Initialize default properties
    self.value = 0.0;
    self.defaultValue = self.value;
    
    self.changeByRotating = NO;
    self.sensitivity = 3;
    self.enableDefaultValue = false;
    
    // style
    UIImage *knobImage = [UIImage imageNamed:@"knob"];
    self.spriteSheet = knobImage;
    self.spriteSize = CGSizeMake(80 * screenScale, 80 * screenScale);
    self.backgroundColor = [UIColor clearColor];
    
    self.userInteractionEnabled = true;
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    [doubleTapGesture setNumberOfTapsRequired:2];
    [self addGestureRecognizer:doubleTapGesture];
}

-(void)doubleTap:(UIGestureRecognizer*)gesture {
    // Reset value to default on double tap

    // Precision mode must fail to register double tap
    if (gesture.state == UIGestureRecognizerStateEnded && self.enableDefaultValue) {
        self.value = self.defaultValue;
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        [self setNeedsDisplay];
    }
}

@synthesize value = _value;

-(float)value {
    return _value;
}

-(void)setValue:(float)value {
    _value = value;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [self setNeedsDisplay];
}

-(void)layoutSubviews {
    // Square up frame
    CGPoint center = self.center;
    CGFloat size = MIN(self.frame.size.width, self.frame.size.height);
    self.frame = CGRectMake(0, 0, size, size);
    self.center = center;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // Begin tracking
    
    UITouch *thisTouch = [touches anyObject];
    tracking = true;
    previousTrackingTouchLocation = [thisTouch locationInView:self];
    
    [self becomeFirstResponder];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (tracking) {
        UITouch *thisTouch = [touches anyObject];
        // Handle tracking touch
        CGPoint thisTouchLocation = [thisTouch locationInView:self];
        
        if (_changeByRotating) {
            CGPoint center = CGPointMake(self.frame.size.width / 2, self.frame.size.height /2);
            
            // Only update if touch is not too close to center
            CGVector vectorFromCenter = CGVectorMake(thisTouchLocation.x - center.x, thisTouchLocation.y - center.y);
            double distanceFromCenter = sqrt((vectorFromCenter.dx * vectorFromCenter.dx) + (vectorFromCenter.dy * vectorFromCenter.dy));
            
            if (distanceFromCenter > center.x / 4.0) {
            
                // Calculate vectors from center to previous touch and new touch
                CGVector prevVector = CGVectorMake(previousTrackingTouchLocation.x - center.x, previousTrackingTouchLocation.y - center.y);
                CGVector thisVector = CGVectorMake(thisTouchLocation.x - center.x, thisTouchLocation.y - center.y);
                
                // Rotation is equivalent to signed angle the between two vectors
                double delta = -atan2(thisVector.dx * prevVector.dy - prevVector.dx * thisVector.dy, prevVector.dx * thisVector.dx + prevVector.dy * thisVector.dy);
                
                // Normalize rotation and adjust value accordingly
                self.value += (delta / (M_PI * 2.0)) / 1.0;

            }
        }
        else {
            CGFloat delta = ((thisTouchLocation.y - previousTrackingTouchLocation.y) * self.sensitivity) / 500.0;
            self.value -= delta;
        }
        
        // Clamp value
        if (self.value > 1.0) {
            self.value = 1.0;
        } else if (self.value < 0.0) {
            self.value = 0.0;
        }
        
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        [self setNeedsDisplay];
        
        previousTrackingTouchLocation = [thisTouch locationInView:self];

    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

    tracking = false;
    
    [self resignFirstResponder];
    [self setNeedsDisplay];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)drawRect:(CGRect)rect
{
    if (self.spriteSheet) {
        // draw control
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSaveGState(ctx);
        CGContextScaleCTM(ctx, 1.0, -1.0);
        if (self.backgroundImage) {
            CGContextDrawImage(ctx, CGRectMake(0, 0, self.bounds.size.width, -self.bounds.size.height), [self.backgroundImage CGImage]);
        }
        
        int sprites = ((self.spriteSheet.size.height / self.spriteSize.height) * [[UIScreen mainScreen] scale]) - 1;
        int frame = (self.value * sprites);
        CGRect sourceRect = CGRectMake(0, frame * self.spriteSize.height, self.spriteSize.width, self.spriteSize.height);
        CGImageRef drawImage = CGImageCreateWithImageInRect([self.spriteSheet CGImage], sourceRect);

        CGContextDrawImage(ctx, CGRectMake(0, 0, self.bounds.size.width, -self.bounds.size.height), drawImage);
        CGImageRelease(drawImage);
        CGContextRestoreGState(ctx);
    }
}

@end
