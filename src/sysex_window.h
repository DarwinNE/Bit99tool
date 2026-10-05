#ifndef SYSEX_WINDOW_H
#define SYSEX_WINDOW_H

#include "bit99_program.h"

#define SYSEX_MAX_DOCUMENTS 99


int send_bitmap(unsigned char *bitmap, const int program);
void sysex_editor_open_bitmap(const unsigned char *bitmap,
                              const int size,
                              bit_map *p_bit_desc,
                              int *order,
                              const int number_of_elements, 
                              const int programNumber,
                              const char *filename);
void sysex_select_last_added_tab(void);

#endif