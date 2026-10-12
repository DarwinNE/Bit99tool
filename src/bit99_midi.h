#ifndef __BIT99_MIDI__
#define __BIT99_MIDI__


#define MIDI_NOTE_ON    0x90
#define MIDI_NOTE_OFF   0x80
#define MIDI_CONTROL    0xB0
#define MIDI_PITCH_WH   0xE0
#define MIDI_PROGRAM    0xC0


typedef enum {BIT01, BIT99} BitModel;

int bit99_send_program_change(unsigned int program);
int bit99_program_dump(BitModel, unsigned int program);
int bit99_program_dump_all(BitModel);
void bit99_set_callback(void);
void bit99_set_output_file(FILE *f);
int bit99_send_file(const char *fn);
int bit99_send_file_f(FILE *fin);
int interpret_MIDI(unsigned char *data, int len);


#endif