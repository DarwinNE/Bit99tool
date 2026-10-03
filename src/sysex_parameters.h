#ifndef SYSEX_PARAMETERS_H
#define SYSEX_PARAMETERS_H
#import <Cocoa/Cocoa.h>

void setParameterInfo(NSControl *control, NSDictionary *info);
NSDictionary *getParameterInfo(NSControl *control);
void octaveChanged(id sender);
void parameterChanged(id sender);

#endif