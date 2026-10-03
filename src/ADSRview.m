#import <Cocoa/Cocoa.h>

#include "ADSRview.h"


@implementation ADSRView
{
    CGFloat _param1;
    CGFloat _param2;
    CGFloat _param3;
    CGFloat _param4;
    SysexDocument *_document;
}

- (void)setDocument:(SysexDocument *)document
             attack:(CGFloat)param1
              decay:(CGFloat)param2
            sustain:(CGFloat)param3
            release:(CGFloat)param4
{
    _param1 = param1;
    _param2 = param2;
    _param3 = param3;
    _param4 = param4;
    _document = document;

    [self setNeedsDisplay:YES];
}


- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    CGFloat left   = 0.0;
    CGFloat right  = 0.0;
    CGFloat top    = 0.0;
    CGFloat bottom = 30.0;

    Bit99ParameterValue data;

    CGFloat attack=0;
    CGFloat decay=0;
    CGFloat sustain=0;
    CGFloat release=0;

    if(_document!=NULL) {
        bit99_decode_parameter(_document->p_bit_desc,
                        _document->bitmap,
                        _param1,
                        &data);
        attack = data.value;
        bit99_decode_parameter(_document->p_bit_desc,
                        _document->bitmap,
                        _param2,
                        &data);
        decay = data.value;
        bit99_decode_parameter(_document->p_bit_desc,
                        _document->bitmap,
                        _param3,
                        &data);
        sustain = data.value;
        bit99_decode_parameter(_document->p_bit_desc,
                        _document->bitmap,
                        _param4,
                        &data);
        release = data.value;
    }

    CGFloat sustain_duration=30;
    CGFloat total = attack + decay + sustain_duration + release;

    if(total<1.0)
        total = 1.0;


    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    CGFloat x0 = left;
    CGFloat x4 = w - right;

    CGFloat y0 = bottom;
    CGFloat yMax = h - top;
    CGFloat scale = (x4 - x0) / total;


    CGFloat x1 = x0 + attack  * scale;
    CGFloat x2 = x1 + decay   * scale;
    CGFloat x3 = x2 + sustain_duration * scale;

    // Sustain
    CGFloat sustainLevel = y0 + sustain * (yMax - y0)/63.0;

    NSBezierPath *path = [NSBezierPath bezierPath];

    [path moveToPoint:NSMakePoint(x0, y0)];

    // Attack
    [path lineToPoint:NSMakePoint(x1, yMax)];

    // Decay
    [path lineToPoint:NSMakePoint(x2, sustainLevel)];

    // Sustain
    [path lineToPoint:NSMakePoint(x3, sustainLevel)];

    // Release
    [path lineToPoint:NSMakePoint(x4, y0)];

    NSColor *color = [NSColor colorWithRed:0.0
                                     green:0.65
                                      blue:0.60
                                     alpha:1.0];

    [color setStroke];

    [path setLineWidth:1.5];
    [path stroke];
}

@end