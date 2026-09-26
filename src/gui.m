#import <Cocoa/Cocoa.h>

#include <stdarg.h>
#include <stdio.h>
#include <limits.h>

#include "gui.h"
#include "macos_midi.h"
#include "bit99_handler.h"


@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    NSWindow *window;

    NSPopUpButton *modelPopup;
    NSTextField *directoryField;
    NSTextField *prefixField;
    NSButton *chooseDirectoryButton;

    NSTextField *programField;
    NSButton *interpretCheckbox;
    NSPopUpButton *midiPopup;

    NSTextView *logView;

    BitConfig config;
}

- (void)appendLog:(NSString *)text;
- (void)updateConfig;

@end


@implementation AppDelegate

- (void)appendLog:(NSString *)text
{
    NSDictionary *attributes = @{
        NSForegroundColorAttributeName : [NSColor labelColor],
        NSFontAttributeName :
            [NSFont monospacedSystemFontOfSize:12
                                         weight:NSFontWeightRegular]
    };

    NSAttributedString *attributedText =
        [[NSAttributedString alloc]
            initWithString:text
                attributes:attributes];

    [[logView textStorage]
        appendAttributedString:attributedText];

    [logView scrollRangeToVisible:
        NSMakeRange([[logView string] length], 0)];
}

- (void)appendLogBold:(NSString *)text
{
    NSDictionary *attributes = @{
        NSForegroundColorAttributeName : [NSColor textBackgroundColor],
        NSBackgroundColorAttributeName : [NSColor textColor],
        NSFontAttributeName :
            [NSFont monospacedSystemFontOfSize:12
                                         weight:NSFontWeightBold]
    };

    NSAttributedString *attributedText =
        [[NSAttributedString alloc]
            initWithString:text
                attributes:attributes];

    [[logView textStorage]
        appendAttributedString:attributedText];

    [logView scrollRangeToVisible:
        NSMakeRange([[logView string] length], 0)];
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    bit99_init(&config);

    /*
     * Window
     */

    NSRect frame = NSMakeRect(0, 0, 600, 700);

    window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];

    [window setTitle:@"Crumar Bit 99/Bit 01 Toolkit"];
    [window setFrameAutosaveName:@"Bit99ToolMainWindow"];
    if (![window setFrameUsingName:@"Bit99ToolMainWindow"])
        [window center];


    /*
     * Main view
     */

    NSView *content = [window contentView];

    /*
     * Version
     */

    NSTextField *version =
        [[NSTextField alloc] initWithFrame:NSMakeRect(30, 640, 540, 20)];

    [version setStringValue:
        @"by Davide Bucci  ·  v. 1.0  ·  2026"];

    [version setFont:
        [NSFont systemFontOfSize:12]];

    [version setTextColor:[NSColor secondaryLabelColor]];
    [version setBezeled:NO];
    [version setDrawsBackground:NO];
    [version setEditable:NO];
    [version setSelectable:NO];

    [content addSubview:version];

    /*
     * Logo
     */

    NSImage *logoImage =
    [[NSImage alloc] initWithContentsOfFile:
        [[NSBundle mainBundle]
            pathForResource:@"bit_logo"
                     ofType:@"png"]];

    NSImageView *logoView =
        [[NSImageView alloc]
            initWithFrame:NSMakeRect(200, 620, 400, 80)];

    [logoView setImage:logoImage];
    [logoView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [logoView setImageFrameStyle:NSImageFrameNone];
    [logoView setFocusRingType:NSFocusRingTypeNone];

    [content addSubview:logoView];

    /*
     * Model
     */

    NSTextField *modelLabel =
        [[NSTextField alloc] initWithFrame:NSMakeRect(30, 585, 150, 24)];

    [modelLabel setStringValue:@"Model:"];

    [modelLabel setBezeled:NO];
    [modelLabel setDrawsBackground:NO];
    [modelLabel setEditable:NO];
    [modelLabel setSelectable:NO];

    [content addSubview:modelLabel];


    modelPopup =
        [[NSPopUpButton alloc]
            initWithFrame:NSMakeRect(100, 585, 260, 28)
            pullsDown:NO];

    [modelPopup addItemWithTitle:@"Crumar Bit 99"];
    [modelPopup addItemWithTitle:@"Crumar Bit 01"];

    [modelPopup selectItemAtIndex:0];

    [content addSubview:modelPopup];


    /*
     * Base file name
     */

    NSTextField *fileLabel =
        [[NSTextField alloc]
            initWithFrame:NSMakeRect(30, 545, 150, 24)];

    [fileLabel setStringValue:@"Base file name:"];

    [fileLabel setBezeled:NO];
    [fileLabel setDrawsBackground:NO];
    [fileLabel setEditable:NO];
    [fileLabel setSelectable:NO];

    [content addSubview:fileLabel];


    directoryField = [[NSTextField alloc] initWithFrame:NSMakeRect
        (30, 545, 420, 24)];
    [directoryField setStringValue:@""];
    [directoryField setPlaceholderString:@"Output directory"];
    [window.contentView addSubview:directoryField];

    chooseDirectoryButton =
        [[NSButton alloc] initWithFrame:NSMakeRect(460, 545, 100, 24)];
    [chooseDirectoryButton setTitle:@"Choose..."];
    [chooseDirectoryButton setBezelStyle:NSBezelStyleRounded];
    [chooseDirectoryButton setTarget:self];
    [chooseDirectoryButton setAction:@selector(chooseDirectory:)];
    [window.contentView addSubview:chooseDirectoryButton];

    prefixField =
        [[NSTextField alloc] initWithFrame:NSMakeRect(30, 510, 420, 24)];
    [prefixField setStringValue:@"BIT99_program"];
    [prefixField setPlaceholderString:@"File name prefix"];
    [window.contentView addSubview:prefixField];


    /*
     * Clear log
     */

    NSButton *clearButton =
        [[NSButton alloc] initWithFrame:NSMakeRect(460, 510, 100, 24)];

    [clearButton setTitle:@"Clear ↓"];
    [clearButton setBezelStyle:NSBezelStyleRounded];
    [clearButton setTarget:self];
    [clearButton setAction:@selector(clearLog:)];

    [window.contentView addSubview:clearButton];

    /*
     * Interpret SysEx
     */

    interpretCheckbox =
        [[NSButton alloc]
            initWithFrame:NSMakeRect(380, 586, 300, 24)];

    [interpretCheckbox setButtonType:NSButtonTypeSwitch];
    [interpretCheckbox setTitle:@"Interpret received SysEx"];
    [interpretCheckbox setState:NSControlStateValueOn];

    [content addSubview:interpretCheckbox];


    /*
     * Log window
     */

    NSScrollView *scrollView =
        [[NSScrollView alloc]
            initWithFrame:NSMakeRect(30, 160, 530, 340)];

    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];

    logView =
        [[NSTextView alloc]
            initWithFrame:NSMakeRect(0, 0, 530, 340)];

    [logView setEditable:NO];
    [logView setSelectable:YES];

    [logView setFont:
        [NSFont monospacedSystemFontOfSize:12
                                    weight:NSFontWeightRegular]];

    [scrollView setDocumentView:logView];

    [content addSubview:scrollView];

    /*
     * Text field for entering the program number
     */

    programField =
        [[NSTextField alloc]
            initWithFrame:NSMakeRect(220, 110, 40, 30)];

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setAllowsFloats:NO];
    [formatter setMinimum:@1];
    [formatter setMaximum:@99];

    [programField setFormatter:formatter];
    [programField setPlaceholderString:@"#"];

    [content addSubview:programField];

    /*
     * Buttons
     */

    NSButton *receiveButton =
        [[NSButton alloc]
            initWithFrame:NSMakeRect(30, 115, 180, 30)];

    [receiveButton setTitle:@"Receive a single program"];
    [receiveButton setBezelStyle:NSBezelStyleRounded];
    [receiveButton setTarget:self];
    [receiveButton setAction:@selector(receiveProgram:)];

    [content addSubview:receiveButton];


    NSButton *receiveAllButton =
        [[NSButton alloc]
            initWithFrame:NSMakeRect(300, 115, 250, 30)];

    [receiveAllButton setTitle:@"Receive all programs"];
    [receiveAllButton setBezelStyle:NSBezelStyleRounded];
    [receiveAllButton setTarget:self];
    [receiveAllButton setAction:@selector(receiveAll:)];

    [content addSubview:receiveAllButton];


    NSButton *sendButton =
        [[NSButton alloc]
            initWithFrame:NSMakeRect(30, 75, 250, 30)];

    [sendButton setTitle:@"Send a file..."];
    [sendButton setBezelStyle:NSBezelStyleRounded];
    [sendButton setTarget:self];
    [sendButton setAction:@selector(sendFile:)];

    [content addSubview:sendButton];


    NSButton *interpretButton =
        [[NSButton alloc]
            initWithFrame:NSMakeRect(300, 75, 250, 30)];

    [interpretButton setTitle:@"Interpret a file..."];
    [interpretButton setBezelStyle:NSBezelStyleRounded];
    [interpretButton setTarget:self];
    [interpretButton setAction:@selector(interpretFile:)];

    [content addSubview:interpretButton];


    /*
     * MIDI interface
     */

    NSTextField *midiLabel =
        [[NSTextField alloc]
            initWithFrame:NSMakeRect(30, 30, 150, 24)];

    [midiLabel setStringValue:@"MIDI interface:"];

    [midiLabel setBezeled:NO];
    [midiLabel setDrawsBackground:NO];
    [midiLabel setEditable:NO];
    [midiLabel setSelectable:NO];

    [content addSubview:midiLabel];


    midiPopup =
        [[NSPopUpButton alloc]
            initWithFrame:NSMakeRect(180, 31, 300, 28)
            pullsDown:NO];

    [self populateMidiPopup];

    [content addSubview:midiPopup];

    /*
     * Build menu
     */


    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    NSMenuItem *appMenuItem =
        [[NSMenuItem alloc] initWithTitle:@""
                                   action:nil
                            keyEquivalent:@""];

    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Bit99Tool"];

    NSMenuItem *aboutItem =
    [[NSMenuItem alloc] initWithTitle:@"About Bit99Tool"
                               action:@selector(orderFrontStandardAboutPanel:)
                        keyEquivalent:@""];

    [appMenu addItem:aboutItem];

    NSMenuItem *quitItem =
        [[NSMenuItem alloc] initWithTitle:@"Quit Bit99Tool"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];

    [quitItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

    [appMenu addItem:quitItem];

    [appMenuItem setSubmenu:appMenu];

    [NSApp setMainMenu:mainMenu];

    [self loadSettings];

    /*
     * Show window
     */

    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

/*
 * Clear log pressing the "Clear" button (you guessed it!)
 */

- (void)clearLog:(id)sender
{
    [logView setString:@""];
}

/*
 * Copy values from GUI into C structure.
 */

- (void)updateConfig
{
    config.model =
        ([modelPopup indexOfSelectedItem] == 0)
            ? BIT99
            : BIT01;

    NSString *directory = [directoryField stringValue];
    NSString *prefix = [prefixField stringValue];

    NSString *name = [directory stringByAppendingPathComponent:prefix];

    snprintf(config.base_file_name,
             sizeof(config.base_file_name),
             "%s",
             [name UTF8String]);

    config.interpret =
        ([interpretCheckbox state] == NSControlStateValueOn);

    int midiDestination = [midiPopup indexOfSelectedItem];

    if (midiDestination >= 0)
        midi_set_destination(midiDestination);
}


/*
 * Buttons
 */

- (void)receiveProgram:(id)sender
{
    [self updateConfig];
    int programNumber = [programField intValue];

    bit99_receive_program_h(&config, programNumber);
}

- (void)receiveAll:(id)sender
{
    [self updateConfig];

    bit99_receive_all_h(&config);
}

- (void)sendFile:(id)sender
{
    [self updateConfig];

    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];

    if ([panel runModal] != NSModalResponseOK)
        return ;

    NSURL *url = [[panel URLs] firstObject];

    char buffer[PATH_MAX];

    if (![url.path getCString:buffer
                     maxLength:sizeof(buffer)
                      encoding:NSUTF8StringEncoding])
        return;


    bit99_send_file_h(&config, buffer);
}

- (void)interpretFile:(id)sender
{
    [self updateConfig];

    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];

    if ([panel runModal] != NSModalResponseOK)
        return ;

    NSURL *url = [[panel URLs] firstObject];

    char buffer[PATH_MAX];

    if (![url.path getCString:buffer
                     maxLength:sizeof(buffer)
                      encoding:NSUTF8StringEncoding])
        return;


    bit99_interpret_file_h(&config, buffer);
}


/*
 * Save interface status.
 */

- (void)saveSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setInteger:[modelPopup indexOfSelectedItem]
                  forKey:@"modelPopup"];

    [defaults setObject:[directoryField stringValue]
                 forKey:@"directory"];

    [defaults setObject:[prefixField stringValue]
                 forKey:@"prefix"];

    [defaults setObject:[programField stringValue]
                 forKey:@"program"];

    [defaults setBool:[interpretCheckbox state] == NSControlStateValueOn
               forKey:@"interpretSysEx"];

    [defaults setObject:[[midiPopup selectedItem] title]
             forKey:@"midiPort"];

    [defaults synchronize];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self saveSettings];
}

/*
 * Load interface settings.
 */

- (void)loadSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSInteger modelIndex =
        [defaults integerForKey:@"modelPopup"];

    if (modelIndex >= 0 &&
        modelIndex < [modelPopup numberOfItems])
        [modelPopup selectItemAtIndex:modelIndex];

    NSString *directory =
        [defaults stringForKey:@"directory"];

    if (directory != nil)
        [directoryField setStringValue:directory];

    NSString *prefix =
        [defaults stringForKey:@"prefix"];

    if (prefix != nil)
        [prefixField setStringValue:prefix];

    NSString *program =
        [defaults stringForKey:@"program"];

    if (program != nil)
        [programField setStringValue:program];

    if ([defaults objectForKey:@"interpretSysEx"] != nil)
        [interpretCheckbox setState:
            [defaults boolForKey:@"interpretSysEx"]
                ? NSControlStateValueOn
                : NSControlStateValueOff];

    NSString *savedPort =
        [defaults stringForKey:@"midiPort"];

    if (savedPort != nil)
        [midiPopup selectItemWithTitle:savedPort];
}

- (void)populateMidiPopup
{
    [midiPopup removeAllItems];

    int n = midi_get_number_of_destinations();

    char buffer[256];

    for (int i = 0; i < n; ++i) {
        if (midi_get_description_destination(i, buffer, sizeof(buffer)) != NULL)
        {
            [midiPopup addItemWithTitle:
                [NSString stringWithUTF8String:buffer]];
        }
    }

    if ([midiPopup numberOfItems] > 0)
        [midiPopup selectItemAtIndex:0];
}


/*
 * Allow application to terminate when window is closed.
 */

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender
{
    return YES;
}


/*
 * Open a directory browser
 */
- (void)chooseDirectory:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:YES];

    if ([panel runModal] == NSModalResponseOK) {
        NSURL *url = [[panel URLs] firstObject];

        if (url != nil) {
            [directoryField setStringValue:[url path]];
        }
    }
}

@end


/*
 * printf-like output to the GUI log.
 */

void gui_printf(const char *format, ...)
{
    char buffer[4096];

    va_list args;

    va_start(args, format);

    vsnprintf(buffer, sizeof(buffer), format, args);

    va_end(args);

    NSString *text =
        [NSString stringWithUTF8String:buffer];

    if (text == nil)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate *delegate =
            (AppDelegate *)[NSApp delegate];

        [delegate appendLog:text];
    });
}

void gui_printf_bold(const char *format, ...)
{
    char buffer[4096];

    va_list args;

    va_start(args, format);

    vsnprintf(buffer, sizeof(buffer), format, args);

    va_end(args);

    NSString *text =
        [NSString stringWithUTF8String:buffer];

    if (text == nil)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate *delegate =
            (AppDelegate *)[NSApp delegate];

        [delegate appendLogBold:text];
    });
}


void gui_run(void)
{
    @autoreleasepool {

        NSApplication *app = [NSApplication sharedApplication];

        AppDelegate *delegate = [[AppDelegate alloc] init];

        [app setDelegate:delegate];

        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        [app run];
    }
}
