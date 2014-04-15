//
//  MyButton.m
//  Copyright (c) 2014年 Everimaging. All rights reserved.
//

#import "MyButton.h"
#import <QuartzCore/QuartzCore.h>

#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

@interface MyButton ()

@property(nonatomic,retain) UIColor *innerBackgroundColor;

@end

@implementation MyButton

- (void)setHighlightBackgroudColor:(UIColor *)highlightBackgroudColor
{
    if (highlightBackgroudColor != _highlightBackgroudColor) {
        _highlightBackgroudColor = highlightBackgroudColor;
        self.selectedBackgroundColor = highlightBackgroudColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (nil == _highlightBackgroudColor) {
        [super setHighlighted:highlighted];
        return;
    }
    
    if (nil == _innerBackgroundColor) {
        self.innerBackgroundColor = self.backgroundColor;
    }
    
    if (highlighted != self.highlighted) {
        if (highlighted)
        {
            self.backgroundColor = _highlightBackgroudColor;
        }
        else if (!self.selected) {
            self.backgroundColor = _innerBackgroundColor;
        }
    }
    
    [super setHighlighted:highlighted];
}

- (void)setSelected:(BOOL)selected
{
    if (nil == _selectedBackgroundColor) {
        [super setSelected:selected];
        return;
    }
    
    if (nil == _innerBackgroundColor) {
        self.innerBackgroundColor = self.backgroundColor;
    }
    
    if (selected != self.selected) {
        if (selected) {
            self.backgroundColor = _selectedBackgroundColor;
        }
        else {
            self.backgroundColor = _innerBackgroundColor;
        }
    }
    
    [super setSelected:selected];
}

@end
