#include <stdio.h>
#include "bit99.h"
#include "gui.h"

enum sysex_state {IDLE, SYSEX_START, SYSEX_MODEL, SYSEX_TYPE,
    ACTIVATE_SPLIT, AS_2,
    LOWER_PC, UPPER_PC,
    SINGLE_P_DUMP, REQUEST_P_DUMP, R_DEVICE, R_PROGRAM,
    BIT_DUMP, EOX} state;

#define MAX_DUMP_SIZE 256
unsigned char bitmap[MAX_DUMP_SIZE];
int dump_pointer=0;

typedef struct bit_map_tag
{
    int parameter;
    char* description;
    int step_size;
} bit_map;

bit_map p_bit_desc[] = {
    {12, "Wheel amount", 4},
    {11, "LFO1 Depth", 4},
    {10, "LFO1 Dynamic range", 4},
    {63, "LFO2 Depth", 4},
    {62, "LFO2 Dynamic range", 4},
    {45, "Detune", -1},                 // Note 1 in the BIT99 manual
    {48, "Volume", 4},
    {34, "Noise", 4},
    {33, "DCO1 Dynamic pulse width", 4},
    {44, "DCO2 Dynamic pulse width", 4},
    { 0, "DCO1 Octave/freq.", -2},      // Note 2 in the BIT99 manual
    { 0, "DCO2 Octave/freq.", -2},
    {32, "DCO1 Pulse width", 8},
    {43, "DCO2 Pulse width", 8},
    {19, "VCF Cut off frequency",4},
    {20, "VCF Resonance", 4},
    {15, "VCF Sustain", 4},
    {21, "VCF Envelope", 4},
    {18, "VCF Tracking", 4},
    {17, "VCF Dynamic Attack", 4},
    {22, "VCF Dynamic Envelope", 4},
    {51, "VCA Sustain", 4},
    {46, "VCA Dynamic attack", 4},
    {47, "VCA Dynamic volume", 4},
    {13, "VCF Attack", 1},
    {14, "VCF Delay", 1},
    {16, "VCF Release", 1},
    {49, "VCA Attack", 1},
    {50, "VCA Delay", 1},
    {52, "VCA Release", 1},
    { 8, "LFO1 Delay", 1},
    {60, "LFO2 Delay", 1},
    { 9, "LFO1 Rate", 1},
    {61, "LFO2 Rate", 1},
    { 0, "LFO flags byte 1", -3},       // Note 3 in the BIT99 manual
    { 0, "LFO flags byte 2", -4},       // Note 4 in the BIT99 manual
    { 0, "DCO flags", -5}               // Note 5 in the BIT99 manual
};

char order[]=
    {34,35,36,30,32,2,1,0,24,25,16,26,19,18,14,15,17,20,10,12,8,7,11,13,9,5,
     22,23,6,27,28,21,29,31,33,4,3};

char* octave[]={"32'", "16'", "8'", "4'"};

char* lfo_wave[]={"No LFO", "triangle", "sawtooth", "pulse"};

bit_map s_bit_desc[] = {
    { 0, "Lower program 1-75", 1},
    { 0, "Upper program 1-75", 1},
    { 0, "Mode", -1},
    {64, "Split Point, key", -2},
    {65, "Upper transpose, key", -2},
    {66, "Lower volume", 4},
    {67, "Upper volume", 4}
};

char* key[] = {
    "C", "C#", "D", "D#", "E", "E#", "F", "F#", "G", "G#", "A", "A#", "B"
};


void bit99_decode_split_double_bitmap(void)
{
    int i;
    int data;

    gui_printf_bold(
        "**************************************************************\n");
    gui_printf_bold(
        "                         SPLIT/DOUBLE BIT MAP                 \n");
    gui_printf_bold(
        "**************************************************************\n");

    for(i=0; i<7; ++i) {
        data=bitmap[2*i]+(bitmap[2*i+1]<<4);
        if(s_bit_desc[i].parameter>0) {
            gui_printf("%2d,",s_bit_desc[i].parameter);
        } else {
            gui_printf("   ");
        }
        gui_printf(" %24s:",s_bit_desc[i].description);
        if(s_bit_desc[i].step_size==-1) {          // Split/double mode
            if(data==1) {
                gui_printf(" Split");
            } else if(data==2) {
                gui_printf(" Double");
            } else {
                gui_printf(" Unrecognized mode!\n");
            }
         } else if(s_bit_desc[i].step_size==-2) {   // Key
            gui_printf(" %d (%s%d)",data+1, key[data%12], data/12+1);
         } else {
            gui_printf(" %d",data/s_bit_desc[i].step_size);
         } 
         gui_printf("\n");
    }
    gui_printf_bold(
        "**************************************************************\n");
}

void bit99_decode_program_bitmap(void)
{
    int i,k;
    int data;
    int value;
    int oct;
    int freq;
    gui_printf_bold(
        "**************************************************************\n");
    gui_printf_bold(
        "                          PROGRAM BIT MAP                     \n");
    gui_printf_bold(
        "**************************************************************\n");
    for(k=0; k<37; ++k) {
        i=order[k];
        //gui_printf("i=%2d --",i);
        data=bitmap[2*i]+(bitmap[2*i+1]<<4);
        if(p_bit_desc[i].parameter>0) {
            gui_printf("%2d,",p_bit_desc[i].parameter);
        } else {
            gui_printf("   ");
        }
        gui_printf(" %24s:",p_bit_desc[i].description);
        if(p_bit_desc[i].step_size==-1) {     // Note 1
            if(data<0x80) {
                value=0;
            } else {
                value=(data-0x80)/2;
            }
            gui_printf(" %d\n", value);
        } else if(p_bit_desc[i].step_size==-2) {     // Note 2
            oct=(int)data/12;
            freq=data-oct*12;
            if(oct>3) {
                fprintf(stderr, "Wrong octave code %d\n", oct);
                oct=3;
            }
            if(freq>11) {
                fprintf(stderr, "Wrong frequency code %d\n", oct);
            }
            gui_printf(" %s, frequency: %d\n", octave[oct],freq);
        } else if(p_bit_desc[i].step_size==-3) {      // Note 3
            gui_printf(" LFO1 controls: ");
            if(data&0x01) gui_printf("DCO1 "); else gui_printf("---- ");
            if(data&0x02) gui_printf("DCO2 "); else gui_printf("---- ");
            if(data&0x04) gui_printf("VCF "); else gui_printf("--- ");
            if(data&0x08) gui_printf("VCA "); else gui_printf("--- ");
            gui_printf("\n                             ");
            gui_printf(" LFO2 controls: ");
            if(data&0x10) gui_printf("DCO1 "); else gui_printf("---- ");
            if(data&0x20) gui_printf("DCO2 "); else gui_printf("---- ");
            if(data&0x40) gui_printf("VCF "); else gui_printf("--- ");
            if(data&0x80) gui_printf("VCA "); else gui_printf("--- ");
            gui_printf("\n");
         } else if(p_bit_desc[i].step_size==-4) {      // Note 4
            //gui_printf("data=%d, ",data);
            int lfo1w=(data&0x03);
            int lfo2w=(data&0x0C)>>2;
            
            gui_printf(" LFO1: %5s,", lfo_wave[lfo1w]);
            gui_printf(" LFO2: %5s ", lfo_wave[lfo2w]);
            if(data&0x70) gui_printf(", VCF INVERT ");

            gui_printf("\n");
        } else if(p_bit_desc[i].step_size==-5) {      // Note 5
            gui_printf(" DCO1: ");
            if(data&0x10) gui_printf("triangle + "); else gui_printf("----- + ");
            if(data&0x04) gui_printf("sawtooth + "); else gui_printf("----- + ");
            if(data&0x01) gui_printf("pulse"); else gui_printf("---");
            gui_printf("\n                             ");
            gui_printf(" DCO2: ");
            if(data&0x20) gui_printf("triangle + "); else gui_printf("----- + ");
            if(data&0x08) gui_printf("sawtooth + "); else gui_printf("----- + ");
            if(data&0x02) gui_printf("pulse"); else gui_printf("---");
            gui_printf("\n");
        } else {
            value=data/p_bit_desc[i].step_size;
            gui_printf(" %d\n", value);
        }
    }
    gui_printf_bold(
        "**************************************************************\n");

}

void bit99_process_byte(int ch)
{
    int channel=0;
    char data1, data2, data3, data4;
    

    switch(state) {
        case IDLE:
            if(ch==0xF0) state=SYSEX_START;
            break;
        case EOX:
            if(ch!=0xF7) fprintf(stderr, "The SYSEX EOX is missing.\n");
            state=IDLE;
            break;
        case SYSEX_START:
            if(ch!=0x25) {
                fprintf(stderr, "Error: Sysex ID is not 0x25 (Crumar BIT)\n");
                state=IDLE;
            } else {
                state=SYSEX_MODEL;
            }
            break;
        case SYSEX_MODEL:
            channel=ch&0x0F;
            if((ch&0x70)==0x20) {
                gui_printf("Sysex for Crumar BIT 99");
            } else if((ch&0x70)==0x10) {
                gui_printf("Sysex for Crumar BIT 01");
            } else {
                fprintf(stderr, "Warning: unknown model ID: 0x%x.\n", 
                    (int)ch&0x70);
            }
            gui_printf(", channel=%d\n", channel);
            state=SYSEX_TYPE;
            break;
        case SYSEX_TYPE:
            switch(ch) {
                case 0x00:
                    state=ACTIVATE_SPLIT;
                    break;
                case 0x01:
                    gui_printf("Inactivate the split mode.\n");
                    state=IDLE;
                    break;
                case 0x02:
                    gui_printf("Activate the double mode.\n");
                    state=IDLE;
                    break;
                case 0x03:
                    gui_printf("Inactivate the double mode.\n");
                    state=IDLE;
                    break;
                case 0x05:
                    state=LOWER_PC;
                    break;
                case 0x06:
                    state=UPPER_PC;
                    break;
                case 0x07:
                    state=SINGLE_P_DUMP;
                    break;
                case 0x09:
                    state=REQUEST_P_DUMP;
                    break;
                default:
                    fprintf(stderr, "Unknown SYSEX type byte 0x%x\n", (int)ch);
                    state=IDLE;
            }
            break;
        case ACTIVATE_SPLIT:
            gui_printf("Activate split: ");
            data1=(char)ch;
            state=AS_2;
            break;
        case AS_2:
            data2=(char)ch;
            gui_printf("split point: %d, transpose: %d", data1, data2);
            state=EOX;
            break;
        case LOWER_PC:
            gui_printf("Lower program change: ");
            data1=(char)ch;
            gui_printf("%d\n",ch);
            state=EOX;
            break;
        case UPPER_PC:
            gui_printf("Upper program change: ");
            data1=(char)ch;
            gui_printf("%d\n",ch);
            state=EOX;
            break;
        case SINGLE_P_DUMP:
            gui_printf("Single program dump: ");
            data1=(char)ch;
            gui_printf("%d\n", data1+1);
            state=BIT_DUMP;
            dump_pointer=0;
            break;
        case REQUEST_P_DUMP:
            gui_printf("Request program dump: ");
            data1=(char)ch;
            channel=ch&0x0F;
            if((data1&0x70)==0x10) {
                gui_printf("BIT01 ");
            } else if((data1&0x70)==0x20) {
                gui_printf("BIT99 ");
            } else {
                gui_printf("????? ");
            }
            gui_printf("channel %d\n", channel+1);
            state=R_PROGRAM; 
            break;
        case R_PROGRAM:
            data2=(char)ch;
            gui_printf("program %d\n", data2+1);
            state=EOX; 
            break;
        case BIT_DUMP:
            // all values <128 are valid, here
            if (ch>127) {   // Found the end of SYSEX.
                state=IDLE;
                gui_printf("Bitmap detected (size=%d)\n", dump_pointer);
                if(dump_pointer==74) {
                    bit99_decode_program_bitmap();
                } else if(dump_pointer==14) {
                    bit99_decode_split_double_bitmap();
                } else {
                    fprintf(stderr, "Size of the bit map does not correspond"
                        " to any known case (program or split/double).\n");
                }
                break;
            }
            if(dump_pointer<MAX_DUMP_SIZE)
                bitmap[dump_pointer++]=(unsigned char)ch;
            else
                fprintf(stderr, 
                    "Error: bitmap larger than %d bytes\n",MAX_DUMP_SIZE);
            break;
        default:
            fprintf(stderr, "Wrong state!\n");
            state=IDLE;
            break;
    }
}

int bit99_sysex(char *fname)
{
    gui_printf("Processing file: %s\n", fname);
    FILE *fin=fopen(fname, "r");
    if(fin==NULL) {
        fprintf(stderr, "Can not open file.\n");
        return 1;
    }
    int ch;
    do {
        ch=fgetc(fin);
        //gui_printf("character code: (%d)\n", ch);
        bit99_process_byte(ch);
    } while(ch!=EOF);
    return 0;
}