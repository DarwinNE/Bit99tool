#ifndef __BIT99_HANDLER__
#define __BIT99_HANDLER__

#include "bit99_midi.h"


#define BUFFER_SIZE 1024


typedef struct {
    BitModel model;
    char full_file_name[BUFFER_SIZE];
    char base_file_name[BUFFER_SIZE];
    int interpret;
    int destination;
} BitConfig;

void bit99_init(BitConfig *config);

void bit99_receive_program_h(BitConfig *config, int pr);
void bit99_receive_all_h(BitConfig *config);
void bit99_send_file_h(const char *filename);
void bit99_interpret_file_h(const char *filename);

int check_file_name(BitConfig *config, int pr);


#endif
