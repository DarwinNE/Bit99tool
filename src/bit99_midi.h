#ifndef __BIT99_MIDI__
#define __BIT99_MIDI__

typedef enum {BIT01, BIT99} BitModel;

int bit99_send_program_change(unsigned int program);
int bit99_program_dump(BitModel, unsigned int program);
int bit99_program_dump_all(BitModel);
void bit99_set_callback(void);
void bit99_set_output_file(FILE *f);
int bit99_send_file(char *fn);
int bit99_send_file_f(FILE *fin);


#endif