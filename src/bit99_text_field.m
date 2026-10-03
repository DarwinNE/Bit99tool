#import <Cocoa/Cocoa.h>

#include "bit99_text_field.h"

@implementation Bit99TextField

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSColor *color = [NSColor colorWithRed:0.0
                     green:0.65
                      blue:0.60
                     alpha:1.0];
    [color setStroke];

    NSRect rect = NSInsetRect(self.bounds, -1.5, -1.5);

    NSBezierPath *border = [NSBezierPath bezierPathWithRect:rect];

    [border setLineWidth:1.0];
    [border stroke];
}

@end