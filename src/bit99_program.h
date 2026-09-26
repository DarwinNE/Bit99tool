#ifndef BIT99_PROGRAM_H
#define BIT99_PROGRAM_H

#include <stddef.h>
#include <stdio.h>

#define BIT99_PROGRAM_PARAMETERS 37
#define BIT99_PROGRAM_BITMAP_SIZE (2 * BIT99_PROGRAM_PARAMETERS)

#define BIT99_SHOWN_PARAMETERS_SIZE 46

#define MAX_DUMP_SIZE 256

#define NOTE1   -1
#define NOTE2   -2
#define NOTE3   -3
#define NOTE4   -4
#define NOTE5   -5
#define NOTE6   -6

#define SEPARATOR -1


typedef struct bit_map_tag
{
    int parameter;
    char* description;
    int step_size;
    int param1;
    int param2;
    int param3;
    int param4;
} bit_map;

/*
 * A decoded representation of one parameter.
 *
 * For normal parameters, value contains the numerical value.
 * Special parameters have additional fields as appropriate.
 */
typedef struct {
    int value;

    /* Used for NOTE parameters */
    int octave;
    int frequency;

    /* Used for LFO flag parameters */
    unsigned char lfo_flags;

    /* Used for LFO waveform parameters */
    int lfo1_wave;
    int lfo2_wave;
    int vcf_invert;

    /* Used for DCO waveform parameters */
    int dco1_triangle;
    int dco1_sawtooth;
    int dco1_pulse;
    int dco2_triangle;
    int dco2_sawtooth;
    int dco2_pulse;
} Bit99ParameterValue;


/*
 * Decode one parameter from a program bitmap.
 *
 * index is the index into p_bit_desc[], NOT the MIDI parameter number.
 */
int bit99_decode_parameter(const unsigned char *bitmap,
                           int index,
                           Bit99ParameterValue *result);


/*
 * Encode one parameter back into the program bitmap.
 */
int bit99_encode_parameter(unsigned char *bitmap,
                           int index,
                           const Bit99ParameterValue *value);

int bit99_sysex(char *fname);
void bit99_decode_program_bitmap(void);
void bit99_decode_split_double_bitmap(void);
int save_bitmap(unsigned char *bitmap, const int program);
int save_bitmap_f(FILE *fout, unsigned char *bitmap, const int program);
#endif