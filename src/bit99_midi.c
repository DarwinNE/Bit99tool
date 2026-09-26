#include <stdio.h>
#include <errno.h>

#include "macos_midi.h"
#include "bit99_midi.h"
#include "gui.h"


enum {false=0, true} sysex_EOX_received;
#define EOX 0xF7

FILE *fout=NULL;

/** Set a file for the output of Sysex.

*/
void bit99_set_output_file(FILE *f)
{
    fout=f;
}

/** Send a program change message.

*/
int bit99_send_program_change(unsigned int program)
{
    unsigned char msg[] = {
        0xC0,   // Program change
        0x00
    };
    msg[1]=(program-1) & 0x7F;
    midi_send(msg, sizeof(msg));
}

/** Dump a single program via Sysex
    @param program the program to be dumped in the range [1, 99].
*/
int bit99_program_dump(BitModel cr, unsigned int program)
{
    unsigned char msg[] = {
        0xF0,   // Sysex start
        0x25,   // Manifacturer ID (Crumar)
        0x20,   // Device ID + channel (0x10 for the BIT 01)
        0x09,   // Request program dump
        0x20,   // Identifies model and channel (0x10 for the BIT 01)
        0x00,   // This is the byte to change for the program 0-98
        0xF7};
    if(cr==BIT01) {
        msg[2]=0x10;
        msg[4]=0x10;
    }
    if (program >99) {
        gui_printf("This is a program for a Bit 99, not a Bit %d!\n",
            program);
        gui_printf("The program number should be between 1 and 99\n");
        return 1;
    } else if (program==0) {
        gui_printf("The program number should be between 1 and 99\n");
        return 1;
    }
    // Create a SYSEX message to request a program dump.
    msg[5]=program-1;
    sysex_EOX_received=false;

    gui_printf("P%2d ",program);
    midi_send(msg, sizeof(msg));

    // wait for EOX. Timeout is 3 seconds
    for(int i=0; i<100 && !sysex_EOX_received; ++i)
        midi_sleep_10ms();

    if(sysex_EOX_received==false) {
        gui_printf("Timeout!\n");
        return 1;
    }


    // Ensure that there is a pause. The BIT 99 does not like to receive
    // Sysex requests too frequently.
    midi_sleep_10ms();
    gui_printf("R ");
    return 0;
}

/** Dump all programs
*/
int bit99_program_dump_all(BitModel m)
{
    gui_printf("Dumping programs 1 to 99:\n");
    for(int i=1; i<100; ++i)
        if (bit99_program_dump(m, i)) return 1;
    gui_printf("\n");
    return 0;
}

/** The callback function that is called when the MIDI subsystem receives
    valid data.
*/
static void bit99_callback(unsigned char *data, int len)
{
    if(fout!=NULL) {
        fwrite(data, sizeof(unsigned char), len, fout);
    }
    if(fout==NULL) {
        gui_printf("MIDI RECEIVED:");
    }
    for (int i = 0; i < len; ++i) {
        if(fout==NULL)
            gui_printf("0x%X ", data[i]);
        if(data[i]==EOX) {
            sysex_EOX_received=true;
        }
    }
    if(fout==NULL)
        gui_printf("\n");
}

/** Send a SYSEX file.
*/
int bit99_send_file_f(FILE *fin)
{
    int ch;
    gui_printf("bit99_send_file_f\n");
    // Reading file character by character
    while ((ch = fgetc(fin)) != EOF) {
        gui_printf("0x%X, ",ch);
        if (midi_send((unsigned char *)&ch, 1))
            return 1;
        if(ch==0xF7) {
            midi_sleep_100ms();
            gui_printf(".");
            fflush(stdout);
        }
    }
    return 0;
}

/** Send a SYSEX file.
*/
int bit99_send_file(char *fn)
{
    FILE *fin=fopen(fn, "rb");
    bit99_send_file_f(fin);
    if(fin==NULL) {
        gui_printf("Could not open file \"%s\" with errno=%d\n", fn, errno);
        return 1;
    }
    gui_printf("Send file!\n");
    fclose(fin);
    gui_printf("\n");
    return 0;
}


/** Send the MIDI callback function to the one provided by this module.
*/
void bit99_set_callback(void)
{
    midi_set_user_callback(bit99_callback);
}