#include "bit99_program.h"

#include <string.h>
#include <stdio.h>
#include <limits.h>

#include "gui.h"
#include "sysex_window.h"

enum sysex_state {IDLE, SYSEX_START, SYSEX_MODEL, SYSEX_TYPE,
    ACTIVATE_SPLIT, AS_2,
    LOWER_PC, UPPER_PC,
    SINGLE_P_DUMP, REQUEST_P_DUMP, R_DEVICE, R_PROGRAM,
    BIT_DUMP, EOX} state;

unsigned char bitmap_p[MAX_DUMP_SIZE];
int dump_pointer=0;
unsigned char program_number;
unsigned char bitmap_size;

#define BITMAP_74 74
#define BITMAP_14 14

char file_name[PATH_MAX];


bit_map p_bit_desc14[BIT99_PROGRAM_PARAMETERS_14] = {
/* 0*/ { 0, "Lower program 1-75", 1, 0, 0, 0, 0},
/* 1*/ { 0, "Upper program 1-75", 1, 0, 0, 0, 0},
/* 2*/ { 0, "Mode", NOTE7, 0, 0, 0, 0},
/* 3*/ { 64, "Split point key", NOTE8, 0, 0, 0, 0},
/* 3*/ { 65, "Upper transpose key", NOTE8, 0, 0, 0, 0},
/* 5*/ { 66, "Lower volume", 4, 0, 0, 0, 0},
/* 6*/ { 67, "Upper volume", 4, 0, 0, 0, 0},
};

int order14[BIT99_SHOWN_PARAMETERS_SIZE_14]=
    {0, 1, 2, 3, 4, 5, 6};

bit_map p_bit_desc74[BIT99_PROGRAM_PARAMETERS_74] = {
/* 0*/ {12, "Wheel amount", 4, 0, 0, 0, 0},
/* 1*/ {11, "LFO1 Depth", 4, 0, 0, 0, 0},
/* 2*/ {10, "LFO1 Dynamic range", 4, 0, 0, 0, 0},
/* 3*/ {63, "LFO2 Depth", 4, 0, 0, 0, 0},
/* 4*/ {62, "LFO2 Dynamic range", 4, 0, 0, 0, 0},
/* 5*/ {45, "Detune", NOTE1, 0, 0, 0, 0},           // Note 1 BIT99 manual
/* 6*/ {48, "Volume", 4, 0, 0, 0, 0},
/* 7*/ {34, "Noise", 4, 0, 0, 0, 0},
/* 8*/ {33, "DCO1 Dynamic pulse width", 4, 0, 0, 0, 0},
/* 9*/ {44, "DCO2 Dynamic pulse width", 4, 0, 0, 0, 0},
/*10*/ { 0, "DCO1 Octave/freq.", NOTE2, 0, 0, 0, 0},  // Note 2 BIT99 manual
/*11*/ { 0, "DCO2 Octave/freq.", NOTE2, 0, 0, 0, 0},
/*12*/ {32, "DCO1 Pulse width", 8, 0, 0, 0, 0},
/*13*/ {43, "DCO2 Pulse width", 8, 0, 0, 0, 0},
/*14*/ {19, "VCF Cut off frequency",4, 0, 0, 0, 0},
/*15*/ {20, "VCF Resonance", 4, 0, 0, 0, 0},
/*16*/ {15, "VCF Sustain", 4, 0, 0, 0, 0},
/*17*/ {21, "VCF Envelope", 4, 0, 0, 0, 0},
/*18*/ {18, "VCF Tracking", 4, 0, 0, 0, 0},
/*19*/ {17, "VCF Dynamic Attack", 4, 0, 0, 0, 0},
/*20*/ {22, "VCF Dynamic Envelope", 4, 0, 0, 0, 0},
/*21*/ {51, "VCA Sustain", 4, 0, 0, 0, 0},
/*22*/ {46, "VCA Dynamic attack", 4, 0, 0, 0, 0},
/*23*/ {47, "VCA Dynamic volume", 4, 0, 0, 0, 0},
/*24*/ {13, "VCF Attack", 1, 0, 0, 0, 0},
/*25*/ {14, "VCF Decay", 1, 0, 0, 0, 0},
/*26*/ {16, "VCF Release", 1, 0, 0, 0, 0},
/*27*/ {49, "VCA Attack", 1, 0, 0, 0, 0},
/*28*/ {50, "VCA Decay", 1, 0, 0, 0, 0},
/*29*/ {52, "VCA Release", 1, 0, 0, 0, 0},
/*30*/ { 8, "LFO1 Delay", 1, 0, 0, 0, 0},
/*31*/ {60, "LFO2 Delay", 1, 0, 0, 0, 0},
/*32*/ { 9, "LFO1 Rate", 1, 0, 0, 0, 0},
/*33*/ {61, "LFO2 Rate", 1, 0, 0, 0, 0},
/*34*/ { 0, "", NOTE3, 0, 0, 0, 0},  // Note 3 BIT99 manual LFO flags byte 1
/*35*/ { 0, "", NOTE4, 0, 0, 0, 0},  // Note 4 BIT99 manual LFO flags byte 2
/*36*/ { 0, "", NOTE5, 0, 0, 0, 0},  // Note 5 BIT99 manual DCO flags
/*37*/ { 0, "", NOTE6, 24,25,16,26}, // Note 6 is an ADSR drawing
/*38*/ { 0, "", NOTE6, 27,28,21,29}
};

#define VCF_ADSR 37
#define VCA_ADSR 38


int order74[BIT99_SHOWN_PARAMETERS_SIZE_74]=
    {34,35,36,SEPARATOR,30,32,2,1,SEPARATOR,24,25,16,26,VCF_ADSR,
     19,18,14,15,17,20,
     SEPARATOR,0,SEPARATOR,10,12,8,
     7,SEPARATOR,11,13,9,5,SEPARATOR,
     22,23,6,SEPARATOR,27,28,21,29,VCA_ADSR,31,33,4,3};

char* octave[OCTAVE_SIZE]={"32'", "16'", "8'", "4'"};

char* lfo_wave[WAVE_SIZE]={"No LFO", "triangle", "sawtooth", "pulse"};

char* key[KEY_SIZE] = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
};

char* keyboard[KEYBOARD_SIZE]= {
    "C1","C#1","D1","D#1","E1","F1","F#1","G1","G#1","A1","A#1","B1",
    "C2","C#2","D2","D#2","E2","F2","F#2","G2","G#2","A2","A#2","B2",
    "C3","C#3","D3","D#3","E3","F3","F#3","G3","G#3","A3","A#3","B3",
    "C4","C#4","D4","D#4","E4","F4","F#4","G4","G#4","A4","A#4","B4",
    "C5","C#5","D5","D#5","E5","F5","F#5","G5","G#5","A5","A#5","B5"
};

void bit99_process_byte(int ch)
{
    int channel=0;
    char data1, data2, data3, data4;


    switch(state) {
        case IDLE:
            if(ch==0xF0) state=SYSEX_START;
            break;
        case EOX:
            if(ch!=0xF7) gui_printf( "The SYSEX EOX is missing.\n");
            state=IDLE;
            break;
        case SYSEX_START:
            if(ch!=0x25) {
                gui_printf( "Error: Sysex ID is not 0x25 (Crumar BIT)\n");
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
                gui_printf( "Warning: unknown model ID: 0x%x.\n",
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
                    gui_printf( "Unknown SYSEX type byte 0x%x\n", (int)ch);
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
            program_number = data1+1;
            gui_printf("%d\n", program_number);
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
                    bit99_decode_program_bitmap74();
                    bitmap_size=BITMAP_74;
                } else if(dump_pointer==14) {
                    bit99_decode_split_double_bitmap();
                    bitmap_size=BITMAP_14;
                } else {
                    gui_printf("Size of the bit map does not correspond"
                        " to any known case (program or split/double).\n");
                }
                break;
            }
            if(dump_pointer<MAX_DUMP_SIZE)
                bitmap_p[dump_pointer++]=(unsigned char)ch;
            else
                gui_printf(
                    "Error: bitmap larger than %d bytes\n",MAX_DUMP_SIZE);
            break;
        default:
            gui_printf("Wrong state!\n");
            state=IDLE;
            break;
    }
}

int bit99_sysex(char *fname)
{
    gui_printf("Processing file: %s\n", fname);
    bitmap_size = 0;


    FILE *fin = fopen(fname, "rb");
    if(fin == NULL) {
        gui_printf( "Can not open file.\n");
        return 1;
    }
    strncpy(file_name, fname, sizeof(file_name));
    int ch;
    do {
        ch = fgetc(fin);
        bit99_process_byte(ch);
    } while(ch != EOF);

    fclose(fin);

    if(bitmap_size==BITMAP_74) {
        gui_printf("Open a 74-byte bitmap.\n");
        sysex_editor_open_bitmap(bitmap_p, dump_pointer,
            p_bit_desc74, order74, BIT99_SHOWN_PARAMETERS_SIZE_74, fname);
    } else if(bitmap_size==BITMAP_14) {
        sysex_editor_open_bitmap(bitmap_p, dump_pointer,
            p_bit_desc14, order14, BIT99_SHOWN_PARAMETERS_SIZE_14, fname);
    } else {
        gui_printf("The file does not contain a program.\n");
    }
        
    return 0;
}


/*
 * Return the 12-bit value represented by one parameter in the bitmap.
 *
 * Every parameter occupies two nibbles:
 *
 *     bitmap[2*i]       = low nibble
 *     bitmap[2*i + 1]   = high nibble
 */
static int
get_parameter_data(const unsigned char *bitmap, int index)
{
    return bitmap[2 * index] |
           (bitmap[2 * index + 1] << 4);
}


/*
 * Store a 8-bit parameter value as two nibbles.
 */
static void
set_parameter_data(unsigned char *bitmap, int index, int data)
{
    bitmap[2 * index]     = data & 0x0f;
    bitmap[2 * index + 1] = (data >> 4) & 0x0f;
    gui_printf("index=%d, data=%d, 0x%X, 0x%X\n", index, data,
        bitmap[2 * index], bitmap[2 * index + 1]);
}


/*
 * Decode one program parameter.
 */
int
bit99_decode_parameter(const bit_map *p_bit_desc,
                       const unsigned char *bitmap,
                       int index,
                       Bit99ParameterValue *result)
{
    int data;

    if (bitmap == NULL || result == NULL ||
        index < 0 || index >= BIT99_PROGRAM_PARAMETERS_74) // TODO: what if 14?
        return -1;

    memset(result, 0, sizeof(*result));

    data = get_parameter_data(bitmap, index);

    switch (p_bit_desc[index].step_size) {

    /*
     * Note 1 in the BIT99 manual:
     * Detune.
     */
    case NOTE1:
        if (data < 0x80)
            result->value = 0;
        else
            result->value = (data - 0x80) / 2;
        break;


    /*
     * Note 2:
     * DCO octave/frequency.
     *
     * The parameter is encoded as:
     *
     *     octave * 12 + frequency
     */
    case NOTE2:
        result->octave = data / 12;
        result->frequency = data % 12;
        gui_printf("decode, octave: %d, freq=%d\n",result->octave,
            result->frequency);

        /*
         * Keep the decoded value available too.  This is convenient
         * for the GUI if it wants to use the encoded note number.
         */
        result->value = data;
        break;


    /*
     * Note 3:
     * LFO control flags.
     *
     * Bits 0..3 = LFO1
     * Bits 4..7 = LFO2
     */
    case NOTE3:
        result->lfo_flags = data;
        result->value = data;
        break;


    /*
     * Note 4:
     * LFO waveforms and VCF inversion.
     */
    case NOTE4:
        result->lfo1_wave = data & 0x03;
        result->lfo2_wave = (data >> 2) & 0x03;
        result->vcf_invert = (data & 0x80) != 0;
        result->value = data;
        break;


    /*
     * Note 5:
     * DCO waveform flags.
     */
    case NOTE5:
        result->dco1_triangle = (data & 0x10) != 0;
        result->dco1_sawtooth = (data & 0x04) != 0;
        result->dco1_pulse = (data & 0x01) != 0;

        result->dco2_triangle = (data & 0x20) != 0;
        result->dco2_sawtooth = (data & 0x08) != 0;
        result->dco2_pulse = (data & 0x02) != 0;
        result->value = data;
        break;

    case NOTE7:
        result->value = data;
        break;

    case NOTE8:
        result->value = data;
        break;

    /*
     * Normal numerical parameter.
     */
    default:
        if (p_bit_desc[index].step_size <= 0)
            return -1;

        result->value = data/p_bit_desc[index].step_size;
        break;
    }

    return 0;
}


/*
 * Encode one program parameter.
 */
int bit99_encode_parameter(const bit_map *p_bit_desc,
                        unsigned char *bitmap,
                        int index,
                        const Bit99ParameterValue *value)
{
    int data;


    if (bitmap == NULL || value == NULL ||
        index < 0 || index >= BIT99_PROGRAM_PARAMETERS_74) // TODO what if 14?
    {
        return -1;
    }

    switch (p_bit_desc[index].step_size) {
        /*
         * Detune.
         *
         * Inverse of:
         *
         *     value = (data - 0x80) / 2
         */
        case NOTE1:
            data = 0x80 + 2 * value->value;
            break;

        /*
         * DCO octave/frequency.
         */
        case NOTE2:
            gui_printf("encode octave: %d, frequency: %d\n",
                value->octave, value->frequency);
            if (value->octave < 0 || value->octave > 3 ||
                value->frequency < 0 || value->frequency > 11)
                return -1;

            data = value->octave * 12 + value->frequency;
            break;

        /*
         * LFO control flags.
         */
        case NOTE3:
            data = value->value;
            break;

        /*
         * LFO waveforms and VCF inversion.
         */
        case NOTE4:
            data = value->value;
            break;


        /*
         * DCO waveform flags.
         */
        case NOTE5:
            data = 0;

            if (value->dco1_triangle)
                data |= 0x10;
            if (value->dco1_sawtooth)
                data |= 0x04;
            if (value->dco1_pulse)
                data |= 0x01;

            if (value->dco2_triangle)
                data |= 0x20;
            if (value->dco2_sawtooth)
                data |= 0x08;
            if (value->dco2_pulse)
                data |= 0x02;

            break;
        case NOTE7:
            data = value->value;
            break;

        case NOTE8:
            data = value->value;
            break;

        /*
         * Normal numerical parameter.
         */
        default:
            if (p_bit_desc[index].step_size <= 0) {
                gui_printf("Programming error: check!\n");
                return -1;
            }

            data = value->value * p_bit_desc[index].step_size;
            break;
    }

    set_parameter_data(bitmap, index, data);

    return 0;
}


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

    for(i=0; i<BIT99_PROGRAM_PARAMETERS_14; ++i) {
        data=bitmap_p[2*i]+(bitmap_p[2*i+1]<<4);
        if(p_bit_desc14[i].parameter>0) {
            gui_printf("%2d,",p_bit_desc14[i].parameter);
        } else {
            gui_printf("   ");
        }
        gui_printf(" %24s:",p_bit_desc14[i].description);
        if(p_bit_desc14[i].step_size==NOTE7) {          // Split/double mode
            if(data==1) {
                gui_printf(" Split");
            } else if(data==2) {
                gui_printf(" Double");
            } else {
                gui_printf(" Unrecognized mode!\n");
            }
         } else if(p_bit_desc14[i].step_size==NOTE2) {   // Key
            gui_printf(" %d (%s%d)",data+1, key[data%12], data/12+1);
         } else {
            gui_printf(" %d",data/p_bit_desc14[i].step_size);
         }
         gui_printf("\n");
    }
    gui_printf_bold(
        "**************************************************************\n");
}

void bit99_decode_program_bitmap74(void)
{
    int k;
    int i;
    Bit99ParameterValue value;
    gui_printf_bold(
        "**************************************************************\n");
    gui_printf_bold(
        "                          PROGRAM BIT MAP                     \n");
    gui_printf_bold(
        "**************************************************************\n");

    for (k = 0; k < BIT99_PROGRAM_PARAMETERS_74; ++k) {

        i = order74[k];
        if (i<0) {
            gui_printf("");
            continue;
        }

        if (p_bit_desc74[i].parameter > 0)
            gui_printf("%2d,", p_bit_desc74[i].parameter);
        else
            gui_printf("   ");

        gui_printf(" %24s:", p_bit_desc74[i].description);

        if (bit99_decode_parameter(p_bit_desc74, bitmap_p, i, &value) != 0) {
            gui_printf(" ERROR\n");
            continue;
        }

        switch (p_bit_desc74[i].step_size) {

        case NOTE1:
            gui_printf(" %d\n", value.value);
            break;

        case NOTE2:
            gui_printf(" %s, frequency: %d\n",
                       octave[value.octave],
                       value.frequency);
            break;

        case NOTE3:
            gui_printf(" LFO1 controls: ");
            gui_printf("%s", value.lfo_flags & 0x01 ? "DCO1 " : "---- ");
            gui_printf("%s", value.lfo_flags & 0x02 ? "DCO2 " : "---- ");
            gui_printf("%s", value.lfo_flags & 0x04 ? "VCF "  : "--- ");
            gui_printf("%s", value.lfo_flags & 0x08 ? "VCA "  : "--- ");

            gui_printf("\n                             ");
            gui_printf(" LFO2 controls: ");
            gui_printf("%s", value.lfo_flags & 0x10 ? "DCO1 " : "---- ");
            gui_printf("%s", value.lfo_flags & 0x20 ? "DCO2 " : "---- ");
            gui_printf("%s", value.lfo_flags & 0x40 ? "VCF "  : "--- ");
            gui_printf("%s", value.lfo_flags & 0x80 ? "VCA "  : "--- ");

            gui_printf("\n");
            break;

        case NOTE4:
            gui_printf(" LFO1: %5s,",
                       lfo_wave[value.lfo1_wave]);
            gui_printf(" LFO2: %5s",
                       lfo_wave[value.lfo2_wave]);

            if (value.vcf_invert)
                gui_printf(", VCF INVERT");

            gui_printf("\n");
            break;

        case NOTE5:
            gui_printf(" DCO1: ");
            gui_printf("%s", value.dco1_triangle
                       ? "triangle + " : "----- + ");
            gui_printf("%s", value.dco1_sawtooth
                       ? "sawtooth + " : "----- + ");
            gui_printf("%s", value.dco1_pulse
                       ? "pulse" : "---");

            gui_printf("\n                             ");
            gui_printf(" DCO2: ");
            gui_printf("%s", value.dco2_triangle
                       ? "triangle + " : "----- + ");
            gui_printf("%s", value.dco2_sawtooth
                       ? "sawtooth + " : "----- + ");
            gui_printf("%s", value.dco2_pulse
                       ? "pulse" : "---");

            gui_printf("\n");
            break;

        default:
            gui_printf(" %d\n", value.value);
            break;
        }
    }

    gui_printf_bold(
        "**************************************************************\n");
}

/**
    Save the current bitmap.
    The size of the bitmap depends on the program number
     1-75 -> 74 bytes ordinary program
    76-99 -> 14 bytes Split/Double bitmap

*/
int save_bitmap_f(FILE *fout, unsigned char *bitmap, const int program)
{
    unsigned char data[] = {
        0xF0,   // Sysex start
        0x25,   // Manifacturer ID (Crumar)
        0x20,   // Device ID + channel (0x10 for the BIT 01)
        0x07,   // Program dump
        0x20,   // Program number
    };

    if(program<1 || program >99)
        return 1;

    data[4] = program-1;

    fwrite(data, 1, 5, fout);
    if(program<76)
        fwrite(bitmap, 1, 74, fout);
    else
        fwrite(bitmap, 1, 14, fout);

    unsigned char endsysx[] = {
        0xF7,   // Sysex end
        0xF7,   // Sysex end
    };

    fwrite(endsysx, 1, 2, fout);

    fclose(fout);
    return 0;
}

int save_bitmap(unsigned char *bitmap, const int program)
{
    FILE *fout = fopen(file_name, "wb");
    if(fout==NULL)
        return 1;
    return save_bitmap_f(fout, bitmap, program);
}

