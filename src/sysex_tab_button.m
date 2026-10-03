#import <Cocoa/Cocoa.h>
#include "sysex_tab_button.h"

@implementation SysexTabButton
{
    NSButton *selectButton;
    NSButton *closeButton;
    id target;
    BOOL _selected;
}

- (void)setLabel:(NSString *)label
{
    [selectButton setAttributedTitle:
        [[NSAttributedString alloc]
            initWithString:label
                attributes:@{
                    NSForegroundColorAttributeName:
                        [NSColor labelColor],
                    NSFontAttributeName:
                        [NSFont boldSystemFontOfSize:12.0]
                }]];
    [self invalidateIntrinsicContentSize];
}

- (void)setSelected:(BOOL)selected
{
    _selected = selected;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect r = NSInsetRect(self.bounds, 0.5, 0.5);

    NSColor *accent =
        [NSColor colorWithCalibratedRed:0.0
                                  green:0.65
                                   blue:0.60
                                  alpha:1.0];

    NSColor *background =
        [NSColor windowBackgroundColor];
    
    if (_selected)
    {
        background =
            [background blendedColorWithFraction:0.10
                                         ofColor:
                                             [NSColor whiteColor]];
    }
    else
    {
        background =
            [background blendedColorWithFraction:0.08
                                         ofColor:
                                             [NSColor blackColor]];
    }
    [background setFill];

    NSBezierPath *path =
        [NSBezierPath bezierPathWithRoundedRect:r
                                        xRadius:2.0
                                        yRadius:2.0];

    [path fill];

    [accent setStroke];
    [path setLineWidth:_selected ? 1.5 : 1.0];
    [path stroke];
}

- (instancetype)initWithTabViewItem:(NSTabViewItem *)item
                              target:(id)aTarget
{
    self = [super initWithFrame:NSMakeRect(0, 0, 160, 28)];

    if (self)
    {
        _tabItem = item;
        target = aTarget;

        selectButton =
            [NSButton buttonWithTitle:[item label]
                               target:target
                               action:@selector(selectTabButton:)];

        [selectButton setBordered:NO];
        [selectButton setButtonType:NSButtonTypeMomentaryPushIn];
        [selectButton setAlignment:NSTextAlignmentCenter];
        [self setLabel:[item label]];
        closeButton =
            [NSButton buttonWithTitle:@"×"
                               target:target
                               action:@selector(closeTabButton:)];

        [closeButton setBordered:NO];

        [self addSubview:selectButton];
        [self addSubview:closeButton];
    }

    return self;
}

/*
 * Size of a toolbar button.
 */
- (NSSize)intrinsicContentSize
{
    NSSize size =
        [[selectButton attributedTitle]
            size];

    return NSMakeSize(size.width + 65.0, 28.0);
}

- (void)layout
{
    [super layout];

    CGFloat closeWidth = 24.0;

    [closeButton setFrame:
        NSMakeRect(self.bounds.size.width - closeWidth,
                   0,
                   closeWidth,
                   self.bounds.size.height)];

    [selectButton setFrame:
        NSMakeRect(8,
                   0,
                   self.bounds.size.width - closeWidth-8,
                   self.bounds.size.height)];
}

@end