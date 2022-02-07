#include <stdio.h>
#include "erl_driver.h"
#include <jack/jack.h>

#include <jack/types.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <unistd.h>  //Header file for sleep(). man 3 sleep for details.
#include <pthread.h>

const double PI = 3.14;
typedef jack_default_audio_sample_t sample_t;
jack_port_t *output_port;
jack_client_t *client;
sample_t inputs;


typedef struct {
    ErlDrvPort port;
} ExJack;

static void
process_silence (jack_nframes_t nframes)
{
    sample_t *buffer = (sample_t *) jack_port_get_buffer (output_port, nframes);
    memset( buffer, 0, sizeof (jack_default_audio_sample_t) * nframes);
}

int process_frames(jack_nframes_t nframes, void *arg) {
    /*
    printf("%d", nframes);
    sample_t *buffer = (sample_t *) jack_port_get_buffer (output_port, nframes);
    jack_nframes_t frames_left = nframes;

    for (unsigned int k=0; k<nframes; k++) {
		buffer[k] = sin(2 * PI * 440 / 44100 * k);
	}
    */
    process_silence(nframes);
    /*
    while (wave_length - offset < frames_left) {
        memcpy (buffer + (nframes - frames_left), wave + offset, sizeof (sample_t) * (wave_length - offset));
        frames_left -= wave_length - offset;
        offset = 0;
    }
    if (frames_left > 0) {
        memcpy (buffer + (nframes - frames_left), wave + offset, sizeof (sample_t) * frames_left);
        offset += frames_left;
    }
    */
    return 0;
}

static ErlDrvData ex_jack_start(ErlDrvPort port, char *buff)
{
    jack_status_t status;
    const char **ports;
    int options = 0, connection;
    ExJack* d = (ExJack*)driver_alloc(sizeof(ExJack));
    d->port = port;


    //BADARG_IF(!enif_get_string(env, argv[0], client_name, sizeof(client_name), ERL_NIF_LATIN1));
    //BADARG_IF(!enif_get_int(env, argv[1], &options));
    //BADARG_IF(!enif_get_string(env, argv[2], server_name, sizeof(server_name), ERL_NIF_LATIN1));

    client = jack_client_open("ex_jack_client", options, &status, "ex_jack_server");
    //unit->num_ports = 0;
    jack_set_process_callback(client, process_frames, 0);


    if (jack_activate (client)) {
        fprintf (stderr, "cannot activate client\n");
        exit(1);
    }

    ports = jack_get_ports (client, NULL, NULL,
            JackPortIsPhysical|JackPortIsOutput);
    if (ports == NULL) {
        fprintf(stderr, "no physical playback ports\n");
        exit (1);
    }

    output_port = jack_port_register (client, "ex_jack_output", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);

    connection = jack_connect (client, jack_port_name(output_port), ports[0]);

    return (ErlDrvData)d;
}

static void ex_jack_stop(ErlDrvData handle)
{
    driver_free((char*)handle);
}


/*
static void *listener(void * arg)
{
    while(1) {
        sleep(1);
        //ExJack* d = (ExJack*)handle;
        printf("Sending message \n");
        //char res = 100;
        //driver_output(d->port, &res, 1);
        //
    }
    return NULL;
}
*/

static void ex_jack_output(ErlDrvData handle, char *buff, 
			       ErlDrvSizeT bufflen)
{
    ExJack* d = (ExJack*)handle;
    char fn = buff[0], arg = buff[1];
    /*
    pthread_t thread_id;
    if (fn == 1) {
        pthread_create(&thread_id, NULL, &listener, NULL);
        res = 1;
    } else if (fn == 2) {
      res = 3;
    }
    */
    inputs = buff[1];
    //driver_output(d->port, &res, 1);
}

ErlDrvEntry example_driver_entry = {
    NULL,			/* F_PTR init, called when driver is loaded */
    ex_jack_start,		/* L_PTR start, called when port is opened */
    ex_jack_stop,		/* F_PTR stop, called when port is closed */
    ex_jack_output,		/* F_PTR output, called when erlang has sent */
    NULL,			/* F_PTR ready_input, called when input descriptor ready */
    NULL,			/* F_PTR ready_output, called when output descriptor ready */
    "ex_jack",		/* char *driver_name, the argument to open_port */
    NULL,			/* F_PTR finish, called when unloaded */
    NULL,                       /* void *handle, Reserved by VM */
    NULL,			/* F_PTR control, port_command callback */
    NULL,			/* F_PTR timeout, reserved */
    NULL,			/* F_PTR outputv, reserved */
    NULL,                       /* F_PTR ready_async, only for async drivers */
    NULL,                       /* F_PTR flush, called when port is about 
				   to be closed, but there is data in driver 
				   queue */
    NULL,                       /* F_PTR call, much like control, sync call
				   to driver */
    NULL,                       /* unused */
    ERL_DRV_EXTENDED_MARKER,    /* int extended marker, Should always be 
				   set to indicate driver versioning */
    ERL_DRV_EXTENDED_MAJOR_VERSION, /* int major_version, should always be 
				       set to this value */
    ERL_DRV_EXTENDED_MINOR_VERSION, /* int minor_version, should always be 
				       set to this value */
    0,                          /* int driver_flags, see documentation */
    NULL,                       /* void *handle2, reserved for VM use */
    NULL,                       /* F_PTR process_exit, called when a 
				   monitored process dies */
    NULL                        /* F_PTR stop_select, called to close an 
				   event object */
};

DRIVER_INIT(ex_jack) /* must match name in driver_entry */
{
    return &example_driver_entry;
}
