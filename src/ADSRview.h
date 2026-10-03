#ifndef ADSRVIEW_H
#define ADSRVIEW_H
#import <Cocoa/Cocoa.h>

#include "sysex_document.h"


@interface ADSRView : NSView

- (void)setDocument:(SysexDocument *)document
            attack:(CGFloat)attack
            decay:(CGFloat)decay
          sustain:(CGFloat)sustain
          release:(CGFloat)release;

@end

#endif