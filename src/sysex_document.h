#ifndef SYSEX_DOCUMENT_H
#define SYSEX_DOCUMENT_H
#import <Cocoa/Cocoa.h>

#include "bit99_program.h"


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
    int programNumber;
}
@end

#endif