#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

#import "gui.h"


int main(void)
{
    NSString *fontPath =
        [[NSBundle mainBundle] pathForResource:@"dseg7-classic-latin-300-normal"
                                        ofType:@"ttf"];

    CFErrorRef error = NULL;

    if (!CTFontManagerRegisterFontsForURL(
            (__bridge CFURLRef)[NSURL fileURLWithPath:fontPath],
            kCTFontManagerScopeProcess,
            &error)) {

        NSLog(@"Error while font registering: %@", error);
        if (error)
            CFRelease(error);
    }
    gui_run();

    return 0;
}
