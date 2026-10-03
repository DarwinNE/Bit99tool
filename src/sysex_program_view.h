#ifndef SYSEX_PROGRAM_VIEW_H
#define SYSEX_PROGRAM_VIEW_H
#import <Cocoa/Cocoa.h>

#include "bit99_text_field.h"
#include "sysex_document.h"


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

#endif