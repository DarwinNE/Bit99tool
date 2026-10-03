#import <Cocoa/Cocoa.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "sysex_window.h"
#include "sysex_tab_button.h"
#include "sysex_document.h"
#include "sysex_program_view.h"
#include "dimensions.h"

@interface SysexEditorWindowController :
    NSWindowController <NSTabViewDelegate>
{
    NSTabView *tabView;
    NSStackView *tabBar;
    NSScrollView *tabScrollView;
    NSTextField *leftIndicator;
    NSTextField *rightIndicator;

    SysexDocument *documents[SYSEX_MAX_DOCUMENTS];
    int documentCount;
}

- (void)addDocument:(SysexDocument *)document;

- (void)programNumberDidChange:(NSNotification *)notification;

@end


static SysexEditorWindowController *editorController = nil;


/*
 * ------------------------------------------------------------------------
 * Window controller
 * ------------------------------------------------------------------------
 */

@implementation SysexEditorWindowController

- (id)init
{
    NSRect frame =
        NSMakeRect(0, 0, 850, 750);

    NSWindow *window =
        [[NSWindow alloc]
            initWithContentRect:frame
                      styleMask:
                          NSWindowStyleMaskTitled |
                          NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable
                        backing:NSBackingStoreBuffered
                          defer:NO];

    self = [super initWithWindow:window];

    if (self) {
    
        [window setTitle:@"Bit 99 SysEx Editor"];
    
        NSView *contentView = [window contentView];
        NSRect contentFrame = [contentView bounds];
    
        CGFloat tabBarHeight = 55.0;
    
        tabView =
            [[NSTabView alloc]
                initWithFrame:
                    NSMakeRect(0,
                               0,
                               contentFrame.size.width,
                               contentFrame.size.height -
                                   tabBarHeight)];
    
        [tabView setAutoresizingMask:
            NSViewWidthSizable |
            NSViewHeightSizable];
    
        [tabView setTabViewType:NSNoTabsNoBorder];
        [tabView setDelegate:self];
    
        tabScrollView =
            [[NSScrollView alloc]
                initWithFrame:
                    NSMakeRect(0,
                               contentFrame.size.height -
                                   tabBarHeight,
                               contentFrame.size.width,
                               tabBarHeight)];
        
        [tabScrollView setHasHorizontalScroller:YES];
        [tabScrollView setHasVerticalScroller:NO];
        [tabScrollView setScrollerStyle:NSScrollerStyleOverlay];
        [tabScrollView setAutohidesScrollers:YES];
        [contentView addSubview:tabView];
        [contentView addSubview:tabScrollView];
        
        [tabScrollView setAutoresizingMask:
            NSViewWidthSizable |
            NSViewMinYMargin];
        
        [tabScrollView setPostsFrameChangedNotifications:YES];
        
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(tabScrollViewFrameDidChange:)
                   name:NSViewFrameDidChangeNotification
                 object:tabScrollView];
        
        
        tabBar =
            [[NSStackView alloc]
                initWithFrame:
                    NSMakeRect(0,
                               0,
                               contentFrame.size.width,
                               tabBarHeight)];
        
        [tabBar setOrientation:
            NSUserInterfaceLayoutOrientationHorizontal];
        
        [tabBar setSpacing:2.0];
        [tabBar setAlignment:NSLayoutAttributeCenterY];
        
        [tabScrollView setDocumentView:tabBar];
        
        NSBox *separator =
            [[NSBox alloc]
                initWithFrame:
                    NSMakeRect(0,
                               contentFrame.size.height -
                                   tabBarHeight,
                               contentFrame.size.width,
                               1)];
        
        [separator setBoxType:NSBoxSeparator];
        [separator setAutoresizingMask:
            NSViewWidthSizable |
            NSViewMinYMargin];
        
        [contentView addSubview:separator];
        documentCount = 0;

        leftIndicator =
            [[NSTextField alloc]
                initWithFrame:
                    NSMakeRect(-3,
                               3,
                               22,
                               tabBarHeight)];
        
        [leftIndicator setStringValue:@"‹"];
        [leftIndicator setEditable:NO];
        [leftIndicator setSelectable:NO];
        [leftIndicator setBordered:NO];
        [leftIndicator setDrawsBackground:YES];
        [leftIndicator setBackgroundColor:
          [[NSColor windowBackgroundColor]
                colorWithAlphaComponent:0.90]];
        [leftIndicator setAlignment:NSTextAlignmentCenter];
        [leftIndicator setFont:
            [NSFont systemFontOfSize:14.0]];
        [leftIndicator setTextColor:
            [NSColor secondaryLabelColor]];
        [leftIndicator setAutoresizingMask:0];
        [leftIndicator setHidden:YES];
        
        [tabScrollView addSubview:leftIndicator];
        
        rightIndicator =
            [[NSTextField alloc]
                initWithFrame:
                    NSMakeRect(
                        tabScrollView.bounds.size.width - 19,
                        3,
                        22,
                        tabBarHeight)];
        
        [rightIndicator setStringValue:@"›"];
        [rightIndicator setEditable:NO];
        [rightIndicator setSelectable:NO];
        [rightIndicator setBordered:NO];
        [rightIndicator setDrawsBackground:YES];
        [rightIndicator setBackgroundColor:
            [[NSColor windowBackgroundColor]
                colorWithAlphaComponent:0.90]];
        [rightIndicator setAlignment:NSTextAlignmentCenter];
        [rightIndicator setFont:
            [NSFont systemFontOfSize:14.0]];
        [rightIndicator setTextColor:
            [NSColor secondaryLabelColor]];

        [tabScrollView addSubview:rightIndicator];
                
        [leftIndicator setAutoresizingMask:
            NSViewMinYMargin];
        
        [rightIndicator setAutoresizingMask:
            NSViewMinXMargin |
            NSViewMinYMargin];
        
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(programNumberDidChange:)
                   name:@"SysexDocumentProgramNumberDidChange"
                 object:nil];

    }
    return self;
}

- (void)tabScrollViewFrameDidChange:(NSNotification *)notification
{
    [self updateTabScrollIndicators];
}

- (void)updateTabScrollIndicators
{
    NSRect visible =
        [[tabScrollView contentView] documentVisibleRect];

    NSRect document =
        [tabBar bounds];

    BOOL overflow =
        NSWidth(document) > NSWidth(visible) + 1.0;

    [leftIndicator setHidden:!overflow];
    [rightIndicator setHidden:!overflow];

    [rightIndicator setFrameOrigin:
        NSMakePoint(NSWidth(tabScrollView.bounds) - 19,
                    3)];
}

/* Slow!
- (void)updateTabBarWidth
{
    CGFloat width =
        [tabBar fittingSize].width;

    CGFloat height =
        [tabScrollView contentSize].height;

    if (width < [tabScrollView contentSize].width)
        width = [tabScrollView contentSize].width;

    [tabBar setFrameSize:
        NSMakeSize(width, height)];

    [self updateTabScrollIndicators];
}
*/

- (void)updateTabBarWidth
{
    CGFloat width = 0.0;

    for (NSView *view in [tabBar arrangedSubviews])
        width += [view intrinsicContentSize].width;

    width += MAX(0,
        ([tabBar arrangedSubviews].count - 1) *
        [tabBar spacing]);

    CGFloat visibleWidth =
        [tabScrollView contentSize].width;

    if (width < visibleWidth)
        width = visibleWidth;

    CGFloat height =
        [tabScrollView contentSize].height;

    [tabBar setFrameSize:
        NSMakeSize(width, height)];

    [self updateTabScrollIndicators];
}

- (void)updateTabLabels
{
    int counts[100] = {0};

    /*
     * Count open tabs for each program number.
     */
    for (NSView *view in [tabBar arrangedSubviews])
    {
        if (![view isKindOfClass:[SysexTabButton class]])
            continue;

        SysexTabButton *button =
            (SysexTabButton *)view;

        SysexDocument *document =
            (SysexDocument *)[button.tabItem identifier];

        int p = document->programNumber;

        if (p >= 0 && p < 100)
            counts[p]++;
    }

    /*
     * Update all tab labels.
     */
    for (NSView *view in [tabBar arrangedSubviews])
    {
        if (![view isKindOfClass:[SysexTabButton class]])
            continue;

        SysexTabButton *button =
            (SysexTabButton *)view;

        NSTabViewItem *item = button.tabItem;

        SysexDocument *document =
            (SysexDocument *)[item identifier];

        int p = document->programNumber;

        NSString *title;

        if (p >= 0 && p < 100 && counts[p] > 1)
        {
            NSString *filename =
                document->filename ?
                    [document->filename lastPathComponent] :
                    @"Untitled";

            title =
                [NSString stringWithFormat:
                    @"%d - %@", p, filename];
        }
        else
        {
            title =
                [NSString stringWithFormat:@"%d", p];
        }

        [item setLabel:title];
        [button setLabel:title];
    }
}

- (void)programNumberDidChange:(NSNotification *)notification
{
    [self updateTabLabels];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addDocument:(SysexDocument *)document
{
    if (documentCount >= SYSEX_MAX_DOCUMENTS)
        return;


    documents[documentCount++] = document;


    NSTabViewItem *item =
        [[NSTabViewItem alloc]
            initWithIdentifier:document];

    NSString *title =
        [NSString stringWithFormat:@"%02d",
            document->programNumber];

    [item setLabel:title];

    /*
     * Leave room for the tab bar.
     */
    NSRect contentFrame =
        [tabView contentRect];


    NSScrollView *scroll =
        [[NSScrollView alloc]
            initWithFrame:contentFrame];

    [scroll setHasVerticalScroller:YES];
    [scroll setHasHorizontalScroller:YES];


    CGFloat contentHeight =
        TOP_MARGIN +
        document->number_of_elements * ROW_HEIGHT +
        TOP_MARGIN;


    NSView *view =
        [[SysexProgramView alloc]
            initWithFrame:
                NSMakeRect(0,
                           0,
                           contentFrame.size.width,
                           contentHeight)
            document:document];


    [scroll setDocumentView:view];

    [item setView:scroll];

    [tabView addTabViewItem:item];

    SysexTabButton *button =
        [[SysexTabButton alloc]
            initWithTabViewItem:item
                         target:self];
    
    [tabBar addArrangedSubview:button];
    
    //[tabView selectTabViewItem:item];   // SLOW!!!
    [tabScrollView
        reflectScrolledClipView:
            [tabScrollView contentView]];
    [self updateTabBarWidth];

    [tabBar scrollRectToVisible:[button frame]];
    
    [self updateTabLabels];
}

- (void)tabView:(NSTabView *)tabView
    didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    for (NSView *view in [tabBar arrangedSubviews])
    {
        if (![view isKindOfClass:[SysexTabButton class]])
            continue;

        SysexTabButton *button =
            (SysexTabButton *)view;

        [button setSelected:
            button.tabItem == tabViewItem];
    }
}

- (void)selectTabButton:(id)sender
{
    NSView *view = [sender superview];

    if (![view isKindOfClass:[SysexTabButton class]])
        return;

    SysexTabButton *button =
        (SysexTabButton *)view;
    //gui_printf("select tab \n");
    [tabView selectTabViewItem:button.tabItem];
}

- (void)closeTabButton:(id)sender
{
    SysexTabButton *button =
        (SysexTabButton *)[sender superview];

    if (![button isKindOfClass:[SysexTabButton class]])
        return;

    NSTabViewItem *item = button.tabItem;

    SysexDocument *document =
        (SysexDocument *)[item identifier];

    /*
     * Remove the document from the document array.
     */
    for (int i = 0; i < documentCount; i++)
    {
        if (documents[i] != document)
            continue;

        for (int j = i; j < documentCount - 1; j++)
            documents[j] = documents[j + 1];

        documents[documentCount - 1] = nil;
        documentCount--;

        break;
    }

    [tabView removeTabViewItem:item];

    [tabBar removeArrangedSubview:button];
    [button removeFromSuperview];
    [self updateTabBarWidth];
    [self updateTabLabels];
}

@end

void sysex_editor_open_bitmap(const unsigned char *bitmap,
                              const int size,
                              bit_map *p_bit_desc,
                              int *order,
                              const int number_of_elements, 
                              const int programNumber,
                              const char *filename)
{
    if(editorController == nil) {
        editorController =
            [[SysexEditorWindowController alloc] init];
    }

    SysexDocument *document = [[SysexDocument alloc] init];

    memcpy(document->bitmap, bitmap, size);
    document->size = size;
    document->order = order;
    document->p_bit_desc = p_bit_desc;
    document->number_of_elements = number_of_elements;
    document->modified = NO;
    document->programNumber = programNumber;


    if(filename != NULL)
        document->filename =
            [NSString stringWithUTF8String:filename];

    [editorController addDocument:document];
    [editorController showWindow:nil];
    [editorController.window makeKeyAndOrderFront:nil];
}
