#ifndef SYSEX_WINDOW_H
#define SYSEX_WINDOW_H

#include "bit99_program.h"


int send_bitmap(unsigned char *bitmap, const int program);
void sysex_editor_open_bitmap(const unsigned char *bitmap,
                              const int size,
                              bit_map *p_bit_desc,
                              int *order,
                              const int number_of_elements, 
                              const char *filename);
#endif