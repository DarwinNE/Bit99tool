#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>


#include "sysex_parameters.h"
#include "sysex_document.h"


static char parameterInfoKey;


void setParameterInfo(NSControl *control, NSDictionary *info)
{
    objc_setAssociatedObject(control,
                             &parameterInfoKey,
                             info,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

NSDictionary *getParameterInfo(NSControl *control)
{
    return objc_getAssociatedObject(control, &parameterInfoKey);
}


/*
 * ------------------------------------------------------------------------
 * Parameter editing
 * ------------------------------------------------------------------------
 */


void octaveChanged(id sender)
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

    if (bit99_encode_parameter(document->p_bit_desc,
                            document->bitmap, index, &value) == 0)
    {
        document->modified = YES;
    }
}

void parameterChanged(id sender)
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
        return;
    }
    /*
     * Split/transpose point
     */
    if (document->p_bit_desc[index].step_size == NOTE8) {
        index = [info[@"index"] intValue];
        int point = (int)[sender indexOfSelectedItem];

        Bit99ParameterValue value;

        bit99_decode_parameter(document->p_bit_desc,
                        document->bitmap, index, &value);
        
        value.value = point;

        if (bit99_encode_parameter(document->p_bit_desc,
                                document->bitmap, index, &value) == 0)
        {
            document->modified = YES;
        }
        return;
    }
}

