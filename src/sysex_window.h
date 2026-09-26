#ifndef SYSEX_WINDOW_H
#define SYSEX_WINDOW_H

int send_bitmap(unsigned char *bitmap, const int program);
void sysex_editor_show(void);
void sysex_editor_open_bitmap(const unsigned char *bitmap,
                              int size,
                              const char *filename);
#endif