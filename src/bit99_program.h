#ifndef BIT99_PROGRAM_H
#define BIT99_PROGRAM_H

#include <stddef.h>
#include <stdio.h>

/* The number of parameters shown is higher than the number of entries in the
   bitmap, as a single entry can yield more than an interface element. */
#define BIT99_PROGRAM_PARAMETERS_74 37
#define BIT99_PROGRAM_BITMAP_SIZE_74 (2 * BIT99_PROGRAM_PARAMETERS_74)
#define BIT99_SHOWN_PARAMETERS_SIZE_74 46

#define BIT99_PROGRAM_PARAMETERS_14 7
#define BIT99_PROGRAM_BITMAP_SIZE_14 (2 * BIT99_PROGRAM_PARAMETERS_14)
#define BIT99_SHOWN_PARAMETERS_SIZE_14 7


#define MAX_DUMP_SIZE 256

#define NOTE1   -1  /* Detune */
#define NOTE2   -2  /* DCO octaves and frequencies */
#define NOTE3   -3  /* LFO flag byte 1 */
#define NOTE4   -4  /* LFO flag byte 2 */
#define NOTE5   -5  /* DCO flags */ 
#define NOTE6   -6  /* ADSR representation */
#define NOTE7   -7  /* Split layer mode */

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
int bit99_decode_parameter(const bit_map *p_bit_desc,
                        const unsigned char *bitmap,
                        int index,
                        Bit99ParameterValue *result);


/*
 * Encode one parameter back into the program bitmap.
 */
int bit99_encode_parameter(const bit_map *p_bit_desc,
                        unsigned char *bitmap,
                        int index,
                        const Bit99ParameterValue *value);

int bit99_sysex(char *fname);
void bit99_decode_program_bitmap74(void);
void bit99_decode_split_double_bitmap(void);
int save_bitmap(unsigned char *bitmap, const int program);
int save_bitmap_f(FILE *fout, unsigned char *bitmap, const int program);
#endif