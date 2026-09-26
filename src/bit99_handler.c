#include <stdio.h>
#include <strings.h>

#include "bit99_handler.h"
#include "bit99_midi.h"
#include "bit99_program.h"
#include "macos_midi.h"
#include "gui.h"

FILE *fout;


void bit99_init(BitConfig *config)
{
    midi_enumerate();
    midi_init_in(1,0);
    //if(config->destination ==-1) {
        config->destination = midi_get_number_of_destinations()-1;
    //}
    midi_init_out(config->destination,0);
    bit99_set_callback();

    config->model = BIT99;

    snprintf(config->base_file_name,
             sizeof(config->base_file_name),
             "");

    config->interpret = 1;
    gui_printf("Configuration done!\n\n");

}

int check_file_name(BitConfig *config, int pr)
{
    if (strcmp(config->base_file_name, "")==0) {
        gui_printf("Enter a file name, first.\n");
        return 1;
    }
    // We already ensured that the place for pr number and .syx exists.
    if(pr>0 && pr<100) {
        sprintf(config->full_file_name, "%s_pr%d.syx",
            config->base_file_name,pr);
    } else {
        sprintf(config->full_file_name, "%s_all.syx",config->base_file_name);
    }
    gui_printf("Full file name: \"%s\"\n", config->full_file_name);
    fout = fopen(config->full_file_name, "w");
    return 0;
}

void bit99_receive_program_h(BitConfig *config, int pr)
{
    int problems=0;
    gui_printf_bold("Receive single program\n");

    gui_printf("Model: %s\n",
           config->model == BIT99 ? "BIT99" : "BIT01");
    if (strcmp(config->base_file_name, "")==0) {
        gui_printf("Enter a file name, first.\n");
        return;
    } else {
        gui_printf("Base file name: %s\n", config->base_file_name);
    }
    if(pr<1 || pr>99) {
        gui_printf("Invalid program, abort\n");
        return;
    }
    gui_printf("Receive program %d\n",pr);

    if(check_file_name(config, pr)==0) {
        bit99_set_output_file(fout);
        problems = bit99_program_dump(config->model, pr);
        fclose(fout);
        fout=NULL;
        bit99_set_output_file(NULL);
        if (problems==0 && config->interpret)
            bit99_sysex(config->full_file_name);
    } else {
        gui_printf("Invalid file name, abort\n");
    }
    if (problems==0) gui_printf("Done\n\n");
}

void bit99_receive_all_h(BitConfig *config)
{
    int problems=0;
    if(check_file_name(config, -1)==0) {
        bit99_set_output_file(fout);
        problems = bit99_program_dump_all(config->model);
        fclose(fout);
        fout=NULL;
        bit99_set_output_file(NULL);
        if (problems==0 && config->interpret)
            bit99_sysex(config->full_file_name);
    } else {
        gui_printf("Invalid base file name, abort.\n");
    }
    if (problems==0) gui_printf("Done\n\n");
}

void bit99_interpret_file_h(BitConfig *config, const char *filename)
{
    gui_printf_bold("Interpret file: %s\n", filename);
    bit99_sysex(filename);
}

void bit99_send_file_h(BitConfig *config, const char *filename)
{
    gui_printf_bold("Send file: %s\n", filename);
    bit99_send_file(filename);
}

