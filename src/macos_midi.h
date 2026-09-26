#ifndef __MACOS_MIDI__
#define __MACOS_MIDI__

int midi_enumerate(void);
int midi_init_out(int destination, int channel);
int midi_init_in(int destination, int channel);
int midi_send(unsigned char *message, int size);
void midi_set_user_callback(void (*cb)(unsigned char *, int));
void midi_sleep_100ms(void);
void midi_sleep_10ms(void);
void wait_for_key(void);
void last_line(void);
int midi_set_destination(int destination);
int midi_get_number_of_destinations(void);
char *midi_get_description_destination(int n, char *buffer, int bufsize);

#endif