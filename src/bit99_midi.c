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
    return 0;
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
        gui_printf("RECEIVED: ");
    }
    for (int i = 0; i < len; ++i) {
        if(fout==NULL) {
            if(!interpret_MIDI(data, len))
                break;
            gui_printf("0x%X ", data[i]);
        }
        if(data[i]==EOX) {
            sysex_EOX_received=true;
        }
    }
    if(fout==NULL)
        gui_printf("\n");
}

extern char* key[];

void print_key(unsigned char v)
{
    unsigned char p=v-12;
    unsigned char octave = p/12;
    unsigned char k=p-octave*12;
    
    gui_printf("%s%d",key[k],octave);
}

/*
 * Interpret the code of the controller. Follow the Tauntek firmware table.
 */
void interpret_controllers(unsigned char v)
{
    switch(v) {
        case 1:
            gui_printf("Mod wheel");
            break;
        case 7:
            gui_printf("Patch volume");
            break;

        case 14:
            gui_printf("DCO1 Octave");
            break;
        case 15:
            gui_printf("DCO1 Freq. offset");
            break;
        case 16:
            gui_printf("DCO1 Tri. Wave");
            break;
        case 17:
            gui_printf("DCO1 Saw. Wave");
            break;
        case 18:
            gui_printf("DCO1 Pulse Wave");
            break;
        case 19:
            gui_printf("DCO1 Pulse Width");
            break;
        case 20:
            gui_printf("DCO1 Dyn PW");
            break;
        
        case 21:
            gui_printf("DCO2 Octave");
            break;
        case 22:
            gui_printf("DCO2 Freq. offset");
            break;
        case 23:
            gui_printf("DCO2 Tri. Wave");
            break;
        case 24:
            gui_printf("DCO2 Saw. Wave");
            break;
        case 25:
            gui_printf("DCO2 Pulse Wave");
            break;
        case 26:
            gui_printf("DCO2 Pulse Width");
            break;
        case 27:
            gui_printf("DCO2 Dyn PW");
            break;
            
        case 28:
            gui_printf("Detune");
            break;
        
        case 29:
            gui_printf("Noise Level");
            break;
            
        case 30:
            gui_printf("VCF Attack");
            break;
        case 31:
            gui_printf("VCF Dyn Attack");
            break;
        case 32:
            gui_printf("VCF Decay");
            break;
        case 33:
            gui_printf("VCF Sustain");
            break;
        case 34:
            gui_printf("VCF Release");
            break;
        case 35:
            gui_printf("VCF Env Amt");
            break;
        case 36:
            gui_printf("VCF Dyn Env Amt");
            break;
        case 37:
            gui_printf("VCF Env Polarity");
            break;
        case 38:
            gui_printf("VCF Key tracking");
            break;    
        
        case 39:
            gui_printf("VCA Dyn Attack");
            break;  
        case 40:
            gui_printf("VCA Decay");
            break;  
        case 41:
            gui_printf("VCA Sustain");
            break;  
        case 42:
            gui_printf("VCA Dyn Env Amt");
            break; 
        
        case 43:
            gui_printf("LFO1 mods DCO1");
            break;  
        case 44:
            gui_printf("LFO1 mods DCO2");
            break;  
        case 45:
            gui_printf("LFO1 mods VCF");
            break;  
        case 46:
            gui_printf("LFO1 mods VCA");
            break;
        case 47:
            gui_printf("LFO1 waveform");
            break;
        
        case 48:
            gui_printf("LFO1 rate");
            break;
        case 49:
            gui_printf("LFO1 dynamic rate");
            break;
        case 50:
            gui_printf("LFO1 delay");
            break;
        case 51:
            gui_printf("LFO1 depth");
            break;
        
        case 52:
            gui_printf("LFO2 mods DCO1");
            break;  
        case 53:
            gui_printf("LFO2 mods DCO2");
            break;  
        case 54:
            gui_printf("LFO2 mods VCF");
            break;  
        case 55:
            gui_printf("LFO2 mods VCA");
            break;
        case 56:
            gui_printf("LFO2 waveform");
            break;
        
        case 57:
            gui_printf("LFO2 rate");
            break;
        case 58:
            gui_printf("LFO2 dynamic rate");
            break;
        case 59:
            gui_printf("LFO2 delay");
            break;
        case 60:
            gui_printf("LFO2 depth");
            break;
        
        
        case 61:
            gui_printf("LFO Wheel Amt");
            break;
        
        case 64:
            gui_printf("Sustain");
            break;
        
        case 71:
            gui_printf("VCF Resonance");
            break;
        case 72:
            gui_printf("VCF Release");
            break;
        case 73:
            gui_printf("VCF Attack");
            break;
        case 74:
            gui_printf("VCF Cutoff");
            break;
        
        case 123:
            gui_printf("All notes off");
            break;
        
        default:
            break;
    }
}

int interpret_MIDI(unsigned char *data, int len)
{
    int i=0;
    switch(data[i]) {
        case MIDI_NOTE_ON:
            if(len>=3) {
                gui_printf("NOTE ON  %d (", data[i+1]);
                print_key(data[i+1]);
                gui_printf("), velocity %d ", data[i+2]);
                if(data[i+2]==0) 
                    gui_printf(" --> OFF");
            }
            break;
        case MIDI_NOTE_OFF:
            if(len>=3) {
                gui_printf("NOTE OFF %d (", data[i+1]);
                print_key(data[i+1]);
                gui_printf("), velocity %d ", data[i+2]);
            }
            break;
        case MIDI_CONTROL:
            if(len>=3) {
                gui_printf("CONTROL %d (",data[i+1]);
                interpret_controllers(data[i+1]);
                gui_printf(") %d",data[i+2]);
            }
            break;
        case MIDI_PITCH_WH:
            if(len>=3) {
                gui_printf("PITCH WHEEL %d, %d",data[i+1],data[i+2]);
            }
            break;
        case MIDI_PROGRAM:
            if(len>=2) {
                gui_printf("PROGRAM CHANGE %d",data[i+1]+1);
            }
            break;
        default:
            return 1;
    }
    return 0;
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
int bit99_send_file(const char *fn)
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