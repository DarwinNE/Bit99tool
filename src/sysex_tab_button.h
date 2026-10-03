#ifndef SYSEX_TAB_BUTTON_H
#define SYSEX_TAB_BUTTON_H
#import <Cocoa/Cocoa.h>


@interface SysexTabButton : NSView

@property(nonatomic, strong) NSTabViewItem *tabItem;

- (instancetype)initWithTabViewItem:(NSTabViewItem *)item
                              target:(id)target;

- (void)setSelected:(BOOL)selected;
- (void)setLabel:(NSString *)label;

@end
#endif