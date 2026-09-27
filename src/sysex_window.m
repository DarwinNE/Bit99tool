#import <Cocoa/Cocoa.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#import <objc/runtime.h>

#include "sysex_window.h"
#include "bit99_program.h"
#include "bit99_midi.h"

#include "gui.h"

extern char *octave[];
extern char *lfo_wave[];
extern char *key[];
extern unsigned char program_number;
extern char file_name[PATH_MAX];


#define SYSEX_MAX_DOCUMENTS 99
#define ROW_HEIGHT          28.0
#define LABEL_WIDTH         200.0
#define CONTROL_WIDTH       150.0
#define NUMBER_WIDTH        60.0
#define BROWSE_WIDTH        80.0
#define PARAM_WIDTH         35.0
#define PADDING             40.0
#define LEFT_MARGIN         50.0
#define TOP_MARGIN          20.0
#define SEPARATION          10.0
#define COLUMN_WIDTH        600.0

#define NROW 21

static char parameterInfoKey;

static void setupDSEG7Popup(NSPopUpButton *popup)
{

    CGFloat size = [[popup font] pointSize];

    //NSFont *font = [NSFont fontWithName:@"DSEG7 Classic" size:size];
    NSColor *color = [NSColor redColor];
    NSColor *back = [NSColor blackColor];

    //[popup setFont:font];

    // Testo visualizzato nel popup chiuso
    NSAttributedString *title =
        [[NSAttributedString alloc]
            initWithString:[popup title]
                attributes:@{
                    //NSFontAttributeName: font,
                    //NSForegroundColorAttributeName: color,
                    //NSBackgroundColorAttributeName: back
                }];

    [[popup cell] setAttributedTitle:title];

    // Testo delle voci del menu
    for (NSMenuItem *item in [[popup menu] itemArray]) {
        [item setAttributedTitle:
            [[NSAttributedString alloc]
                initWithString:[item title]
                    attributes:@{
                        //NSFontAttributeName: font,
                        //NSForegroundColorAttributeName: color
                    }]];
    }
}

static void setupDSEG7Field(NSTextField *field)
{
    CGFloat size = [[field font] pointSize]*1.4;

    [field setFont:[NSFont fontWithName:@"DSEG7 Classic" size:size]];
    [field setTextColor:[NSColor redColor]];
    [field setBackgroundColor:[NSColor blackColor]];
    [field setDrawsBackground:YES];
    [field setAlignment:NSTextAlignmentRight];
    [field setBezeled:NO];
    [field setBordered:NO];

}

@interface Bit99TextField : NSTextField
@end

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


@interface SysexDocument : NSObject
{
@public
    unsigned char bitmap[MAX_DUMP_SIZE];    // Pointer to the bitmap.
    int size;                       // Size in bytes of the bitmap.
    bit_map *p_bit_desc;            // P. to the description of parameters.
    unsigned int *order;            // P. to the order vector.
    unsigned int number_of_elements;// No of elements in the two previous arrays
                                    // i.e. number of shown interface elements.
    BOOL modified;                  // Flag: has it been modified or not.
    NSString *filename;             // Current filename.
}
@end

@implementation SysexDocument
@end


@interface ADSRView : NSView

- (void)setDocument:(SysexDocument *)document
            attack:(CGFloat)attack
            decay:(CGFloat)decay
          sustain:(CGFloat)sustain
          release:(CGFloat)release;

@end

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


static void setParameterInfo(NSControl *control, NSDictionary *info)
{
    objc_setAssociatedObject(control,
                             &parameterInfoKey,
                             info,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSDictionary *getParameterInfo(NSControl *control)
{
    return objc_getAssociatedObject(control, &parameterInfoKey);
}

@interface SysexProgramView : NSView
{
    SysexDocument *document;
    NSMutableArray *controls;
    NSMutableArray *adsrViews;
    NSTextField *fileNameField;
    Bit99TextField *programField;
}
- (id)initWithFrame:(NSRect)frame
           document:(SysexDocument *)doc;
@end


@interface SysexEditorWindowController :
    NSWindowController <NSTabViewDelegate>
{
    NSTabView *tabView;

    SysexDocument *documents[SYSEX_MAX_DOCUMENTS];
    int documentCount;
}
- (void)addDocument:(SysexDocument *)document;
@end


static SysexEditorWindowController *editorController = nil;


/*
 * ------------------------------------------------------------------------
 * Utility
 * ------------------------------------------------------------------------
 */

static NSTextField *createLabel(NSString *text, NSRect frame)
{
    NSTextField *label =
        [[NSTextField alloc] initWithFrame:frame];

    [label setStringValue:text];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];

    return label;
}


/*
 * ------------------------------------------------------------------------
 * Parameter editing
 * ------------------------------------------------------------------------
 */

static void programNumberChanged(id sender)
{
    int valuep = [sender intValue];

    if (valuep < 1)
        valuep = 0;
    else if (valuep > 74)
        valuep = 74;

    [sender setIntValue:valuep];
    program_number = valuep;
}

static void octaveChanged(id sender)
{
    NSDictionary *info = getParameterInfo(sender);

    SysexDocument *document =
        (SysexDocument *)[info[@"document"] pointerValue];

    int index = [info[@"index"] intValue];
    Bit99ParameterValue value;

    if (bit99_decode_parameter(document->p_bit_desc,
                            document->bitmap, index, &value) != 0)
    {
        return;
    }

    int valuep = [sender intValue];

    int octave = (int)[sender indexOfSelectedItem];

    value.octave = octave;
    gui_printf("octave: %d\n",octave);

    if (bit99_encode_parameter(document->p_bit_desc,
                            document->bitmap, index, &value) == 0)
    {
        document->modified = YES;
    }
}

static void parameterChanged(id sender)
{
    NSDictionary *info = getParameterInfo(sender);

    SysexDocument *document =
        (SysexDocument *)[info[@"document"] pointerValue];

    int index = [info[@"index"] intValue];

    Bit99ParameterValue value;

    int valuep = [sender intValue];

    if (valuep < 0)
        valuep = 0;
    else if (valuep > 63)
        valuep = 63;

    [sender setIntValue:valuep];

    if (bit99_decode_parameter(document->p_bit_desc,
                            document->bitmap, index, &value) != 0)
    {
        return;
    }

    /*
     * Normal numerical parameter or detune.
     */
    if (document->p_bit_desc[index].step_size > 0 ||
        document->p_bit_desc[index].step_size == NOTE1)
    {

        value.value = [sender intValue];

        if (bit99_encode_parameter(document->p_bit_desc,
                            document->bitmap, index, &value) == 0)
        {
            document->modified = YES;
        }
        return;
    }

    /*
     * Note parameters.
     *
     * The popup contains the notes.
     */
    if (document->p_bit_desc[index].step_size == NOTE2) {
        int freq = (int)[sender indexOfSelectedItem];

        value.frequency = freq % 12;

        if (bit99_encode_parameter(document->p_bit_desc,
                            document->bitmap, index, &value) == 0)
        {
            document->modified = YES;
        }
        return;
    }

    /*
     * Note 3 in the manual, LFO flag byte 1.
     */
    if (document->p_bit_desc[index].step_size == NOTE3) {
        index = [info[@"index"] intValue];
        int bit   = [info[@"bit"] intValue];

        Bit99ParameterValue value;

        bit99_decode_parameter(document->p_bit_desc,
                        document->bitmap, index, &value);

        if ([sender state] == NSControlStateValueOn)
            value.value |= (1 << bit);
        else
            value.value &= ~(1 << bit);

        if (bit99_encode_parameter(document->p_bit_desc,
                                document->bitmap, index, &value) == 0)
        {
            document->modified = YES;
        }
        return;
    }

    /*
     * Split mode
     */
    if (document->p_bit_desc[index].step_size == NOTE7) {
        index = [info[@"index"] intValue];
        int mode = (int)[sender indexOfSelectedItem];

        Bit99ParameterValue value;

        bit99_decode_parameter(document->p_bit_desc,
                        document->bitmap, index, &value);
        
        value.value = mode+1;

        if (bit99_encode_parameter(document->p_bit_desc,
                                document->bitmap, index, &value) == 0)
        {
            document->modified = YES;
        }
        gui_printf("parameter (mode) change: %d\n",value.value);

        return;
    }
}


/*
 * ------------------------------------------------------------------------
 * Program view
 * ------------------------------------------------------------------------
 */

@implementation SysexProgramView

- (void)browseFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];

    [panel beginWithCompletionHandler:
        ^(NSModalResponse result) {

            if (result != NSModalResponseOK)
                return;

            NSURL *url = [[panel URLs] firstObject];

            if (url == nil)
                return;

            NSString *path = [url path];

            gui_printf("Selected file: %s\n",
                       [path UTF8String]);

            [fileNameField setStringValue:path];
            snprintf(file_name, sizeof(file_name), "%s", [path UTF8String]);
        }];
}

- (void)fileNameChanged:(id)sender
{
    gui_printf("File name changed!\n");

    NSDictionary *info = getParameterInfo(sender);

    SysexDocument *document =
        (SysexDocument *)[info[@"document"] pointerValue];

    NSString *string = [sender stringValue];
    const char *fileName = [string UTF8String];

    gui_printf("File name: %s\n", fileName);
    strncpy(file_name, fileName, sizeof(file_name)-1);
    file_name[sizeof(file_name) - 1] = '\0';
}


double calcX(int idx)
{
    if(idx>=NROW)
        return COLUMN_WIDTH;
    else
        return 0;
}

double adjustY(int idx)
{
    if(idx==NROW)
        return (NROW+7)*ROW_HEIGHT;
    else
        return 0;
}

- (id)initWithFrame:(NSRect)frame
           document:(SysexDocument *)doc
{
    self = [super initWithFrame:frame];

    if (self) {
        document = doc;
        controls = [[NSMutableArray alloc] init];
        adsrViews = [[NSMutableArray alloc] init];

        CGFloat totalwidth = 2*COLUMN_WIDTH;
        CGFloat y = frame.size.height - TOP_MARGIN - ROW_HEIGHT;

        NSTextField *fileNameLabel =
            createLabel(@"File name:",
                        NSMakeRect(LEFT_MARGIN+PADDING,
                                   y,
                                   LABEL_WIDTH,
                                   22));
        [self addSubview:fileNameLabel];

        fileNameField =
            [[NSTextField alloc]
                initWithFrame:
                    NSMakeRect(
                        LEFT_MARGIN + PADDING + LABEL_WIDTH,
                        y,
                        totalwidth-
                            (LEFT_MARGIN + PADDING+LABEL_WIDTH+BROWSE_WIDTH+10),
                        22)];

        [fileNameField setStringValue:[NSString
            stringWithUTF8String:file_name]];
        NSDictionary *info = @{
            @"document":
                [NSValue valueWithPointer:(
                __bridge const void *)document],
            @"index":
                @(101)
        };

        setParameterInfo(fileNameField, info);

        [fileNameField setTarget:self];
        [fileNameField setAction:
            @selector(fileNameChanged:)];

        [self addSubview:fileNameField];
        [controls addObject:fileNameField];

        NSButton *browseButton =
            [[NSButton alloc]
                initWithFrame:
                    NSMakeRect(
                        totalwidth - BROWSE_WIDTH,
                        y,
                        BROWSE_WIDTH,
                        22)];

        [browseButton setTitle:@"Browse..."];
        [browseButton setButtonType:NSButtonTypeMomentaryPushIn];
        [browseButton setTarget:self];
        [browseButton setAction:@selector(browseFile:)];

        [self addSubview:browseButton];
        float min_y=y;

        y -= ROW_HEIGHT;

        NSTextField *programLabel =
            createLabel(@"Program number:",
                        NSMakeRect(LEFT_MARGIN+PADDING,
                                   y,
                                   LABEL_WIDTH,
                                   22));
        [self addSubview:programLabel];

        programField =
            [[Bit99TextField alloc]
                initWithFrame:
                    NSMakeRect(
                        LEFT_MARGIN + PADDING + LABEL_WIDTH,
                        y,
                        NUMBER_WIDTH,
                        22)];


        NSNumberFormatter *formatter_p = [[NSNumberFormatter alloc] init];
        [formatter_p setNumberStyle:NSNumberFormatterDecimalStyle];
        [formatter_p setMinimum:@1];
        [formatter_p setMaximum:@99];

        [programField setIntValue:program_number];

        NSDictionary *info1 = @{
            @"document":
                [NSValue valueWithPointer:(
                __bridge const void *)document],
            @"index":
                @(100)
        };

        setParameterInfo(programField, info1);
        setupDSEG7Field(programField);

        [programField setTarget:self];
        [programField setAction:
            @selector(programNumberChanged:)];

        [self addSubview:programField];
        [controls addObject:programField];
        y -= ROW_HEIGHT;

        NSBox *separator_p = [[NSBox alloc]
        initWithFrame:NSMakeRect(
                0, y+ROW_HEIGHT/2, totalwidth, 1)];
        [separator_p setBoxType:NSBoxSeparator];
        [self addSubview:separator_p];

        y -= ROW_HEIGHT;
        
        /*
        gui_printf("Number of elements = %d\n", document->number_of_elements);
        
        for (unsigned int k = 0; k < document->number_of_elements; ++k) {
            int i = document->order[k];
            gui_printf("(k=%d, i=%d) ",k,i);
        }
        gui_printf("\n");
        return 0;
        */

        for (unsigned int k = 0; k < document->number_of_elements; ++k) {
            int i = document->order[k];
            y += adjustY(k);

            if(i<0) {
                NSBox *separator = [[NSBox alloc]
                    initWithFrame:NSMakeRect(calcX(k)+
                        0, y+ROW_HEIGHT/2, COLUMN_WIDTH, 1)];
                [separator setBoxType:NSBoxSeparator];
                [self addSubview:separator];
                y -= ROW_HEIGHT;
                continue;
            }

            NSString *description =
                [NSString stringWithUTF8String:
                    document->p_bit_desc[i].description];


            /*
             * Parameter label.
             */
            NSTextField *label =
                createLabel(description,
                            NSMakeRect(calcX(k)+LEFT_MARGIN+PADDING,
                                       y,
                                       LABEL_WIDTH,
                                       22));

            [self addSubview:label];

            /*
             * Parameter number.
             */
            if (document->p_bit_desc[i].parameter > 0) {
                NSTextField *number =
                    createLabel(
                        [NSString stringWithFormat:
                            @"%d",
                            document->p_bit_desc[i].parameter],
                        NSMakeRect(calcX(k)+LEFT_MARGIN,
                                   y,
                                   PARAM_WIDTH,
                                   22));
                setupDSEG7Field(number);
                NSColor *darkRed =
                    [NSColor.redColor colorWithAlphaComponent:0.5];
                [number setTextColor:darkRed];
                [self addSubview:number];
            }

            /*
             * Normal numerical parameter, or detune.
             */
            if (document->p_bit_desc[i].step_size > 0 ||
                document->p_bit_desc[i].step_size == NOTE1) {

                Bit99ParameterValue value;

                bit99_decode_parameter(document->p_bit_desc,
                                document->bitmap, i, &value);

                Bit99TextField *field =
                    [[Bit99TextField alloc]
                        initWithFrame:
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN + PADDING + LABEL_WIDTH,
                                y,
                                NUMBER_WIDTH,
                                22)];

                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
                [formatter setMinimum:@0];
                [formatter setMaximum:@63];

                [field setIntValue:value.value];

                NSDictionary *info = @{
                    @"document":
                        [NSValue valueWithPointer:(
                        __bridge const void *)document],
                    @"index":
                        @(i)
                };

                setParameterInfo(field, info);
                setupDSEG7Field(field);

                [field setTarget:self];
                [field setAction:
                    @selector(parameterChanged:)];

                [self addSubview:field];
                [controls addObject:field];
            }

            /*
             * Note / octave parameter.
             */
            else if (document->p_bit_desc[i].step_size == NOTE2) {
                Bit99ParameterValue value;

                bit99_decode_parameter(document->p_bit_desc,
                                    document->bitmap, i, &value);

                NSPopUpButton *popup1 =
                    [[NSPopUpButton alloc]
                        initWithFrame:
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN + PADDING + LABEL_WIDTH,
                                y,
                                CONTROL_WIDTH/2-SEPARATION/2,
                                22)];
                setupDSEG7Popup(popup1);
                NSPopUpButton *popup2 =
                    [[NSPopUpButton alloc]
                        initWithFrame:
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN + PADDING +
                                 LABEL_WIDTH+CONTROL_WIDTH/2+
                                SEPARATION,
                                y,
                                CONTROL_WIDTH/2-SEPARATION/2,
                                22)];
                setupDSEG7Popup(popup2);


                for (int octaveIndex = 0; octaveIndex < 4; ++octaveIndex) {
                    NSString *name =
                            [NSString stringWithFormat:
                                @"%s",
                                octave[octaveIndex]];

                        [popup1 addItemWithTitle:name];
                }
                for (int keyIndex = 0; keyIndex < 12; ++keyIndex) {
                    NSString *name =
                            [NSString stringWithFormat:
                                @"%s",
                                key[keyIndex]];

                        [popup2 addItemWithTitle:name];
                }
                [popup1 selectItemAtIndex:value.octave];
                [popup2 selectItemAtIndex:value.frequency];
    

                NSDictionary *info1 = @{
                    @"document":
                        [NSValue valueWithPointer:(
                        __bridge const void *)document],
                    @"index":
                        @(i)
                };

                setParameterInfo(popup1, info1);

                [popup1 setTarget:self];
                [popup1 setAction:@selector(octaveChanged:)];

                [self addSubview:popup1];
                [controls addObject:popup1];


                NSDictionary *info2 = @{
                    @"document":
                        [NSValue valueWithPointer:(
                        __bridge const void *)document],
                    @"index":
                        @(i)
                };

                setParameterInfo(popup2, info2);

                [popup2 setTarget:self];
                [popup2 setAction:@selector(parameterChanged:)];

                [self addSubview:popup2];
                [controls addObject:popup2];

            }

            /*
             * LFO flags, byte 1
             */
            else if (document->p_bit_desc[i].step_size == NOTE3) {
                Bit99ParameterValue value;

                bit99_decode_parameter(document->p_bit_desc,
                                    document->bitmap, i, &value);

                const char *names[] = {
                    "DCO1", "DCO2", "VCF", "VCA"
                };

                for (int lfo = 0; lfo < 2; ++lfo) {

                    NSTextField *label =
                        createLabel(
                            lfo == 0 ? @"LFO1 to" : @"LFO2 to",
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN+PARAM_WIDTH,
                                y - lfo * ROW_HEIGHT,
                                LABEL_WIDTH,
                                22));

                    [self addSubview:label];
                    gui_printf("index= %d value.value=%d\n", i, value.value);

                    for (int j = 0; j < 4; ++j) {
                        int bit = lfo * 4 + j;

                        NSButton *check =
                            [[NSButton alloc]
                                initWithFrame:
                                    NSMakeRect(calcX(k)+
                                        LEFT_MARGIN + LABEL_WIDTH +
                                            j * 75,
                                        y - lfo * ROW_HEIGHT,
                                        70,
                                        22)];

                        [check setButtonType:NSButtonTypeSwitch];
                        [check setTitle:
                            [NSString stringWithUTF8String:names[j]]];

                        [check setState:
                            (value.value & (1 << bit))
                                ? NSControlStateValueOn
                                : NSControlStateValueOff];

                        NSDictionary *info = @{
                            @"document":
                                [NSValue valueWithPointer:(
                                    __bridge const void *)document],
                            @"index": @(i),
                            @"bit": @(bit)
                        };

                        setParameterInfo(check, info);

                        [check setTarget:self];
                        [check setAction:
                            @selector(parameterChanged:)];

                        [self addSubview:check];
                        [controls addObject:check];
                    }
                }

                y -= 2 * ROW_HEIGHT;
            }
            /*
             * NOTE4, a few bits for the LFOs
             */

            else if (document->p_bit_desc[i].step_size == NOTE4) {
                Bit99ParameterValue value;

                bit99_decode_parameter(document->p_bit_desc,
                                    document->bitmap, i, &value);

                const char *wave_names[] = {
                    "No LFO",
                    "triangle",
                    "sawtooth",
                    "pulse"
                };

                for (int lfo = 0; lfo < 2; ++lfo) {
                    NSTextField *label =
                        createLabel(
                            lfo == 0 ? @"LFO1 wave" : @"LFO2 wave",
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN+PARAM_WIDTH,
                                y - lfo * ROW_HEIGHT,
                                LABEL_WIDTH,
                                22));

                    [self addSubview:label];

                    NSPopUpButton *popup =
                        [[NSPopUpButton alloc]
                            initWithFrame:
                                NSMakeRect(calcX(k)+
                                    LEFT_MARGIN + LABEL_WIDTH,
                                    y - lfo * ROW_HEIGHT,
                                    LABEL_WIDTH,
                                    22)];

                    setupDSEG7Popup(popup);

                    for (int j = 0; j < 4; ++j) {
                        [popup addItemWithTitle:
                            [NSString stringWithUTF8String:wave_names[j]]];
                    }

                    int wave =
                        (value.value >> (lfo * 2)) & 0x03;

                    [popup selectItemAtIndex:wave];

                    NSDictionary *info = @{
                        @"document":
                            [NSValue valueWithPointer:(
                                __bridge const void *)document],
                        @"index": @(i),
                        @"mask": @(0x03),
                        @"shift": @(lfo * 2)
                    };

                    setParameterInfo(popup, info);

                    [popup setTarget:self];
                    [popup setAction:@selector(parameterChanged:)];

                    [self addSubview:popup];
                    [controls addObject:popup];
                }

                NSButton *check =
                    [[NSButton alloc]
                        initWithFrame:
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN+LABEL_WIDTH,
                                y - 2 * ROW_HEIGHT,
                                CONTROL_WIDTH,
                                22)];

                [check setButtonType:NSButtonTypeSwitch];
                [check setTitle:@"VCF invert"];

                [check setState:
                    (value.value & 0x80)
                        ? NSControlStateValueOn
                        : NSControlStateValueOff];

                NSDictionary *info = @{
                    @"document":
                        [NSValue valueWithPointer:(
                            __bridge const void *)document],
                    @"index": @(i),
                    @"mask": @(0x80)
                };

                setParameterInfo(check, info);

                [check setTarget:self];
                [check setAction:
                    @selector(parameterChanged:)];

                [self addSubview:check];
                [controls addObject:check];

                y -= 3 * ROW_HEIGHT;
            }

            /*
             * NOTE5: bits for the DCOs.
             */
            else if (document->p_bit_desc[i].step_size == NOTE5)  {
                Bit99ParameterValue value;

                bit99_decode_parameter(document->p_bit_desc,
                                    document->bitmap, i, &value);

                const char *dco_names[] = {
                    "triangle", "sawtooth", "pulse"
                };

                const int dco_bits[2][3] = {
                    { 0x10, 0x04, 0x01 },
                    { 0x20, 0x08, 0x02 }
                };

                for (int dco = 0; dco < 2; ++dco) {
                    NSTextField *label =
                        createLabel(
                            dco == 0 ? @"DCO1" : @"DCO2",
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN+PARAM_WIDTH,
                                y - dco * ROW_HEIGHT,
                                LABEL_WIDTH,
                                22));

                    [self addSubview:label];

                    for (int j = 0; j < 3; ++j) {

                        NSButton *check =
                            [[NSButton alloc]
                                initWithFrame:
                                    NSMakeRect(calcX(k)+
                                        LEFT_MARGIN + LABEL_WIDTH +
                                            j * 85,
                                        y - dco * ROW_HEIGHT,
                                        80,
                                        22)];

                        [check setButtonType:NSButtonTypeSwitch];
                        [check setTitle:
                            [NSString stringWithUTF8String:dco_names[j]]];

                        [check setState:
                            (value.value & dco_bits[dco][j])
                                ? NSControlStateValueOn
                                : NSControlStateValueOff];

                        NSDictionary *info = @{
                            @"document":
                                [NSValue valueWithPointer:(
                                    __bridge const void *)document],
                            @"index": @(i),
                            @"mask": @(dco_bits[dco][j])
                        };

                        setParameterInfo(check, info);

                        [check setTarget:self];
                        [check setAction:
                            @selector(parameterChanged:)];

                        [self addSubview:check];
                        [controls addObject:check];
                    }
                }
                y -= 2 * ROW_HEIGHT;
            }

            /*
             * ADSR drawing (and a separator below it)
             */
            else if (document->p_bit_desc[i].step_size == NOTE6) {
                ADSRView *adsr = [[ADSRView alloc]
                    initWithFrame:NSMakeRect(calcX(k)+
                        LEFT_MARGIN + PADDING + LABEL_WIDTH+CONTROL_WIDTH,
                        y, 150, 150)];
                [self addSubview:adsr];

                [adsr setDocument:document
                           attack:document->p_bit_desc[i].param1
                            decay:document->p_bit_desc[i].param2
                          sustain:document->p_bit_desc[i].param3
                          release:document->p_bit_desc[i].param4];
                [adsrViews addObject:adsr];

                NSBox *separator = [[NSBox alloc]
                initWithFrame:NSMakeRect(calcX(k)+
                        0, y+ROW_HEIGHT/2, COLUMN_WIDTH, 1)];
                [separator setBoxType:NSBoxSeparator];
                [self addSubview:separator];
            }
            /*
             * Slit/double selector
             */
            else if (document->p_bit_desc[i].step_size == NOTE7)  {
                Bit99ParameterValue value;
    
                bit99_decode_parameter(document->p_bit_desc,
                                    document->bitmap, i, &value);
                NSPopUpButton *popup =
                    [[NSPopUpButton alloc]
                        initWithFrame:
                            NSMakeRect(calcX(k)+
                                LEFT_MARGIN + LABEL_WIDTH + PADDING,
                                y,
                                CONTROL_WIDTH,
                                22)];
    
                setupDSEG7Popup(popup);
                [popup addItemWithTitle: @"Split"];
                setupDSEG7Popup(popup);
                [popup addItemWithTitle: @"Double"];
    
                NSDictionary *info = @{
                    @"document":
                        [NSValue valueWithPointer:(
                            __bridge const void *)document],
                    @"index": @(i)
                };
                setParameterInfo(popup, info);
                gui_printf("Split/double %d\n", value.value);
                [popup selectItemAtIndex:value.value-1];
                
                
                [popup setTarget:self];
                [popup setAction:@selector(parameterChanged:)];
                [self addSubview:popup];
                [controls addObject:popup];
            }

            y -= ROW_HEIGHT;
            if (y<min_y)
                min_y=y;
        }

        NSButton *saveButton =
            [[NSButton alloc]
                initWithFrame:
                    NSMakeRect(calcX(document->number_of_elements)+
                        LEFT_MARGIN,
                        y - ROW_HEIGHT,
                        80,
                        24)];

        [saveButton setTitle:@"SAVE"];
        [saveButton setButtonType:NSButtonTypeMomentaryPushIn];
        [saveButton setTarget:self];
        [saveButton setAction:@selector(saveProgram:)];

        [self addSubview:saveButton];

        NSButton *uploadButton =
            [[NSButton alloc]
                initWithFrame:
                    NSMakeRect(calcX(document->number_of_elements)+
                        LEFT_MARGIN+100,
                        y - ROW_HEIGHT,
                        80,
                        24)];

        [uploadButton setTitle:@"Send!"];
        [uploadButton setButtonType:NSButtonTypeMomentaryPushIn];
        [uploadButton setTarget:self];
        [uploadButton setAction:@selector(uploadProgram:)];

        [self addSubview:uploadButton];
        y -= 2*ROW_HEIGHT;

        NSBox *separator = [[NSBox alloc]
            initWithFrame:NSMakeRect(calcX(document->number_of_elements)+
                0, y+ROW_HEIGHT/2, COLUMN_WIDTH, 1)];
        [separator setBoxType:NSBoxSeparator];
        [self addSubview:separator];

        NSBox *vert_separator =
            [[NSBox alloc]
                initWithFrame:
                    NSMakeRect(COLUMN_WIDTH,min_y+ROW_HEIGHT/2.0,
                        1,
                        (NROW+7) * ROW_HEIGHT)];

        [vert_separator setBoxType:NSBoxCustom];
        [vert_separator setBorderType:NSNoBorder];
        [vert_separator setFillColor:[NSColor separatorColor]];

        // Add the vertical separator only if needed (i.e. we are using two
        // columns).
        if(document->number_of_elements>NROW)
            [self addSubview:vert_separator];
        
        if (y<min_y)
            min_y=y;

        min_y -= ROW_HEIGHT;

        CGFloat contentHeight = frame.size.height - min_y;
        CGFloat dy = contentHeight - frame.size.height;

        [self setFrameSize: NSMakeSize(totalwidth, contentHeight)];

        for (NSView *view in [self subviews]) {
            NSRect r = [view frame];
            r.origin.y += dy;
            [view setFrame:r];
        }
        [self setFrameSize:NSMakeSize(totalwidth, contentHeight)];
    }

    return self;
}

- (void)saveProgram:(id)sender
{
    gui_printf("Save the file!\n");
    int program= [programField intValue];
    save_bitmap(document->bitmap, program);
}

- (void)uploadProgram:(id)sender
{
    gui_printf("Upload the program!\n");
    int program= [programField intValue];
    if(send_bitmap(document->bitmap, program)) {
        gui_printf("Could not send data.\n");
    } else {
        gui_printf("Jolly good!\n");
    }
}

- (void)octaveChanged:(id)sender
{
    octaveChanged(sender);
}

- (void)parameterChanged:(id)sender
{
    parameterChanged(sender);

    [self setNeedsDisplay:YES];
    for (ADSRView *adsr in adsrViews)
        [adsr setNeedsDisplay:YES];
}

@end


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

        tabView =
            [[NSTabView alloc]
                initWithFrame:
                    [[window contentView] bounds]];

        [tabView setAutoresizingMask:
            NSViewWidthSizable |
            NSViewHeightSizable];

        [tabView setDelegate:self];

        [[window contentView] addSubview:tabView];

        documentCount = 0;
    }

    return self;
}


- (void)addDocument:(SysexDocument *)document
{
    if (documentCount >= SYSEX_MAX_DOCUMENTS)
        return;


    documents[documentCount++] = document;


    NSTabViewItem *item =
        [[NSTabViewItem alloc]
            initWithIdentifier:
                @(documentCount - 1)];


    NSString *title =
        document->filename ?
            [document->filename lastPathComponent] :
            @"Untitled";


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
    [scroll setHasHorizontalScroller:NO];
    [scroll setBorderType:NSNoBorder];


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

    [tabView selectTabViewItem:item];
}

@end

void sysex_editor_open_bitmap(const unsigned char *bitmap,
                              const int size,
                              bit_map *p_bit_desc,
                              int *order,
                              const int number_of_elements, 
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

    if(filename != NULL)
        document->filename =
            [NSString stringWithUTF8String:filename];

    [editorController addDocument:document];
    [editorController showWindow:nil];
    [editorController.window makeKeyAndOrderFront:nil];
}

/*
 * Send the current bitmap. If program>0, then change the current program
 * and go back to the one specified so that the settings are taken into
 * account. This is not done if program is less than 1.
 */
int send_bitmap(unsigned char *bitmap, const int program)
{
    NSString *tmpDir = NSTemporaryDirectory();
    int r=0;

    char template[PATH_MAX];
    snprintf(template, sizeof(template),
             "%sbit99-XXXXXX", [tmpDir fileSystemRepresentation]);

    int fd = mkstemp(template);
    gui_printf("File template: %s\n", template);

    if (fd == -1) {
        gui_printf("Could not create temp file!\n");
        return 1;
    }

    FILE *f = fdopen(fd, "w+b");

    if (f == NULL) {
        gui_printf("Could not open temp file!\n");
        close(fd);
        unlink(template);
        return 1;
    }
    if((r=save_bitmap_f(f, bitmap, program))) {
        gui_printf("Problems writing the temp file.\n");
    } else {
            fclose(f);

        gui_printf("Temp file written.\n");
        r=bit99_send_file(template);
        if(r)
            gui_printf("Problems!\n");
    }

    unlink(template);

    if (program<1 || program >99)
        return r;

    if(program!=74)
        bit99_send_program_change(74);
    else
        bit99_send_program_change(73);

    bit99_send_program_change(program);

    return r;
}
