#import <Cocoa/Cocoa.h>

#include "sysex_program_view.h"
#include "bit99_text_field.h"
#include "sysex_document.h"
#include "dimensions.h"
#include "sysex_parameters.h"
#include "ADSRview.h"
#include "bit99_midi.h"


#include "gui.h"

extern char *octave[];
extern char *lfo_wave[];
extern char *key[];
extern char *keyboard[];

extern char file_name[PATH_MAX];

/*
 * ------------------------------------------------------------------------
 * Utility
 * ------------------------------------------------------------------------
 */
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
        return 1;
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


static void setupDSEG7Popup(NSPopUpButton *popup)
{

    //CGFloat size = [[popup font] pointSize];

    //NSFont *font = [NSFont fontWithName:@"DSEG7 Classic" size:size];
    //NSColor *color = [NSColor redColor];
    //NSColor *back = [NSColor blackColor];

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

-(void)programNumberChanged:(id)sender
{
    NSDictionary *info = getParameterInfo(sender);
    SysexDocument *doc =
        (SysexDocument *)[info[@"document"] pointerValue];

    int valuep = [sender intValue];


    if (valuep < 1)
        valuep = 0;
    else if (valuep > 99)
        valuep = 99;

    [sender setIntValue:valuep];
    doc->programNumber=valuep;
    
    gui_printf("programNumberChanged: %d\n",
           doc->programNumber);

    
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"SysexDocumentProgramNumberDidChange"
                          object:document];
}

- (void)fileNameChanged:(id)sender
{
    gui_printf("File name changed!\n");

//    NSDictionary *info = getParameterInfo(sender);

    /*SysexDocument *document =
        (SysexDocument *)[info[@"document"] pointerValue];*/

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

        [programField setIntValue:document->programNumber];
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


                for (int octaveIndex = 0; octaveIndex < OCTAVE_SIZE;
                    ++octaveIndex)
                {
                    NSString *name =
                            [NSString stringWithFormat:
                                @"%s",
                                octave[octaveIndex]];

                        [popup1 addItemWithTitle:name];
                }
                for (int keyIndex = 0; keyIndex < KEY_SIZE; ++keyIndex) {
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
                    { 4, 2, 0 },
                    { 5, 3, 1 }
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
                            (value.value & (1 << dco_bits[dco][j]))
                                ? NSControlStateValueOn
                                : NSControlStateValueOff];

                        NSDictionary *info = @{
                            @"document":
                                [NSValue valueWithPointer:(
                                    __bridge const void *)document],
                            @"index": @(i),
                            @"bit": @(dco_bits[dco][j])
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
            /*
             * Slit/double selector
             */
            else if (document->p_bit_desc[i].step_size == NOTE8)  {
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
    
                for(int keyboardIndex=0; keyboardIndex<KEYBOARD_SIZE;
                    ++keyboardIndex)
                {
                    [popup addItemWithTitle: [NSString stringWithFormat:
                                @"%s",
                                keyboard[keyboardIndex]]];
                }
                NSDictionary *info = @{
                    @"document":
                        [NSValue valueWithPointer:(
                            __bridge const void *)document],
                    @"index": @(i)
                };
                setParameterInfo(popup, info);
                [popup selectItemAtIndex:value.value];
                
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
        [vert_separator setTransparent:YES];
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
    gui_printf("Called parameterChanged action\n");
    parameterChanged(sender);

    [self setNeedsDisplay:YES];
    for (ADSRView *adsr in adsrViews)
        [adsr setNeedsDisplay:YES];
}

@end