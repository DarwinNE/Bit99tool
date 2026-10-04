#include <CoreMIDI/MIDIServices.h>
#include <CoreFoundation/CFRunLoop.h>
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include "macos_midi.h"

/*
    This file contains macOS-specific code for accessing to MIDI ports
    and other OS-related stuff (waiting for a while, wait for a keypress, etc)
*/


MIDIPortRef     gOutPort;
int             gOutChannel = 0;
MIDIEndpointRef gDest;
int             gInChannel = 0;

void (*user_callback)(unsigned char *data, int len);

void midi_set_user_callback(void (*cb)(unsigned char*, int))
{
    user_callback = cb;
}

static void midi_callback(const MIDIPacketList *pktlist, void *refCon,
    void *connRefCon)
{
    (void)refCon;           // Silence unused warnings.
    (void)connRefCon;

    if(user_callback==NULL) {
        fprintf(stderr, "Received data, but no callback is defined.\n");
        return;
    }
    if (gOutPort != 0 && gDest != 0) {
        MIDIPacket *packet = (MIDIPacket *)pktlist->packet; // remove const (!)
        for (unsigned int j = 0; j < pktlist->numPackets; ++j) {
            if (user_callback!=NULL)
                user_callback(packet->data, packet->length);
            packet = MIDIPacketNext(packet);
        }
    }
}

Byte buffer[1024];

int midi_send(unsigned char *message, int size)
{

    if(size>(int)sizeof(buffer)) {
        fprintf(stderr, "Error: MIDI message too large.\n");
        return 1;
    }
    // For simplicity, we create one packetList for each message.
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
    MIDIPacket *packet = MIDIPacketListInit(packetList);

    // Byte is defined as unsigned char
    // https://developer.apple.com/documentation/kernel/byte
    Byte *msg = (Byte*) message;

    packet = MIDIPacketListAdd(packetList, sizeof(buffer), packet, 0,
        size, msg);

    MIDISend(gOutPort, gDest, packetList);
    return 0;
}

int midi_enumerate(void)
{
    // enumerate devices (not really related to purpose of the echo program
    // but shows how to get information about devices)
    int i, n;
    CFStringRef pname;
    char name[256];

    //n = MIDIGetNumberOfDevices();
    n = MIDIGetNumberOfDestinations();
    for (i = 0; i < n; ++i) {
        //MIDIDeviceRef dev = MIDIGetDevice(i);
        // only output:
        MIDIEndpointRef dev = MIDIGetDestination(i);

        MIDIObjectGetStringProperty(dev, kMIDIPropertyName, &pname);
        CFStringGetCString(pname, name, sizeof(name), 0);
        printf("%d - name = %s\n", i, name);

        CFRelease(pname);
    }
    return n;
}

int midi_get_number_of_destinations(void)
{
    return MIDIGetNumberOfDestinations();
}

char *midi_get_description_destination(int n, char *buffer, int bufsize)
{
    if(n<0 || (unsigned long)n>=MIDIGetNumberOfDestinations())
        return NULL;

    CFStringRef pname;
    MIDIObjectGetStringProperty(MIDIGetDestination(n), kMIDIPropertyName,
        &pname);
    CFStringGetCString(pname, buffer, bufsize, kCFStringEncodingUTF8);
    CFRelease(pname);

    return buffer;
}

int midi_init_in(int channel)
{
    int i;
    // find the number of inputs
    int n = MIDIGetNumberOfSources();

    // create client and ports
    MIDIClientRef client;
    MIDIClientCreate(CFSTR("MIDI CRUMAR BIT99"), NULL, NULL, &client);

    MIDIPortRef inPort;
    MIDIInputPortCreate(client, CFSTR("Input port"), midi_callback, NULL,
        &inPort);

    gInChannel=channel;

    // open connections from all sources
    printf("%d sources\n", n);
    for (i = 0; i < n; ++i) {
        MIDIEndpointRef src = MIDIGetSource(i);
        MIDIPortConnectSource(inPort, src, NULL);
    }
    return 0;
}

int midi_set_destination(int destination)
{
    int n = MIDIGetNumberOfDestinations();
    if (n > 0 && destination<n) {
        gDest = MIDIGetDestination(destination);
        return 0;
    }
    return 1;
}

int midi_init_out(int destination, int channel)
{

    // create client and ports
    MIDIClientRef client;
    MIDIClientCreate(CFSTR("MIDI CRUMAR BIT99"), NULL, NULL, &client);

    //MIDIPortRef inPort;
    MIDIOutputPortCreate(client, CFSTR("Output port"), &gOutPort);

    gOutChannel=channel;
    midi_set_destination(destination);

    CFStringRef pname;
    char name[64];
    if (gDest != 0) {
        MIDIObjectGetStringProperty(gDest, kMIDIPropertyName, &pname);
        CFStringGetCString(pname, name, sizeof(name), 0);
        printf("Output to channel %d of %s\n", gOutChannel + 1, name);
        CFRelease(pname);
    } else {
        printf("No MIDI destinations present\n");
        return 1;
    }
    return 0;
}

void midi_sleep_100ms(void)
{
    usleep(100*1000);
}

void midi_sleep_10ms(void)
{
    usleep(10*1000);
}

void last_line(void)
{
    struct winsize w;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
    printf("\033[%d;1H", w.ws_row);
}

void wait_for_key(void)
{
    struct termios oldt, newt;
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    getchar();
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
}