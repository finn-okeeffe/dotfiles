/*
 * Relay MIDI from an original Arturia KeyLab Essential to Ardour.
 *
 * The controller's faders can stop at CC value 1 rather than 0 after their
 * polarity is inverted.  This relay linearly rescales that 1-127 range to
 * MIDI's full 0-127 range for the nine fader CCs used by the Ardour map;
 * every other MIDI event passes unchanged.
 *
 * It deliberately uses the ALSA runtime library and kernel UAPI header so it
 * builds on a stock Fedora installation without alsa-lib-devel.
 */

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

#include <sound/asequencer.h>

typedef struct _snd_seq snd_seq_t;

int snd_seq_open (snd_seq_t **seqp, const char *name, int streams, int mode);
int snd_seq_close (snd_seq_t *handle);
int snd_seq_client_id (snd_seq_t *handle);
int snd_seq_set_client_name (snd_seq_t *handle, const char *name);
int snd_seq_create_simple_port (snd_seq_t *seq, const char *name,
                                unsigned int caps, unsigned int type);
int snd_seq_event_input (snd_seq_t *seq, struct snd_seq_event **ev);
int snd_seq_event_output_direct (snd_seq_t *seq, struct snd_seq_event *ev);

enum {
    SND_SEQ_OPEN_DUPLEX = 3,
    KEYLAB_CHANNEL = 15, /* MIDI channel 16, zero-based */
    FIRST_FADER_CC = 20,
    LAST_FADER_CC = 28,
    KEYLAB_FADER_MINIMUM = 1,
    MIDI_CC_MAXIMUM = 127,
};

static volatile sig_atomic_t keep_running = 1;

static void
stop (int signal_number)
{
    (void) signal_number;
    keep_running = 0;
}

static void
print_usage (const char *program_name)
{
    printf ("Usage: %s [--verbose]\n", program_name);
    puts ("\nCreates an ALSA MIDI relay that scales KeyLab fader CC values 1-127");
    puts ("to 0-127. Connect the KeyLab to its input port and its output port to Ardour.");
}

static int
report_alsa_error (const char *operation, int error_code)
{
    fprintf (stderr, "%s failed (%d)\n", operation, error_code);
    return 1;
}

static int
is_keylab_fader_event (const struct snd_seq_event *event)
{
    return event->type == SNDRV_SEQ_EVENT_CONTROLLER &&
           event->data.control.channel == KEYLAB_CHANNEL &&
           event->data.control.param >= FIRST_FADER_CC &&
           event->data.control.param <= LAST_FADER_CC;
}

static int
scale_keylab_fader_value (int value)
{
    /*
     * The inverted KeyLab faders report 1 at their physical minimum. Map
     * that observed 1-127 range onto the complete MIDI CC range, rounding to
     * the nearest integer. Retaining an already-received zero is harmless and
     * makes the relay safe if a controller firmware revision emits one.
     */
    if (value <= KEYLAB_FADER_MINIMUM) {
        return 0;
    }
    if (value >= MIDI_CC_MAXIMUM) {
        return MIDI_CC_MAXIMUM;
    }

    return ((value - KEYLAB_FADER_MINIMUM) * MIDI_CC_MAXIMUM +
            (MIDI_CC_MAXIMUM - KEYLAB_FADER_MINIMUM) / 2) /
           (MIDI_CC_MAXIMUM - KEYLAB_FADER_MINIMUM);
}

int
main (int argc, char **argv)
{
    const char *program_name = argv[0];
    int verbose = 0;
    int input_port;
    int output_port;
    int client_id;
    int error_code;
    snd_seq_t *sequencer = NULL;

    if (argc == 2 && strcmp (argv[1], "--help") == 0) {
        print_usage (program_name);
        return 0;
    }
    if (argc == 2 && strcmp (argv[1], "--verbose") == 0) {
        verbose = 1;
    } else if (argc != 1) {
        print_usage (program_name);
        return 2;
    }

    error_code = snd_seq_open (&sequencer, "default", SND_SEQ_OPEN_DUPLEX, 0);
    if (error_code < 0) {
        return report_alsa_error ("Opening the ALSA sequencer", error_code);
    }

    if ((error_code = snd_seq_set_client_name (sequencer,
                                                "KeyLab Essential fader scale")) < 0) {
        snd_seq_close (sequencer);
        return report_alsa_error ("Naming the ALSA client", error_code);
    }

    input_port = snd_seq_create_simple_port (
        sequencer,
        "KeyLab input",
        SNDRV_SEQ_PORT_CAP_WRITE | SNDRV_SEQ_PORT_CAP_SUBS_WRITE,
        SNDRV_SEQ_PORT_TYPE_APPLICATION);
    if (input_port < 0) {
        snd_seq_close (sequencer);
        return report_alsa_error ("Creating the input port", input_port);
    }

    output_port = snd_seq_create_simple_port (
        sequencer,
        "Ardour output",
        SNDRV_SEQ_PORT_CAP_READ | SNDRV_SEQ_PORT_CAP_SUBS_READ,
        SNDRV_SEQ_PORT_TYPE_APPLICATION);
    if (output_port < 0) {
        snd_seq_close (sequencer);
        return report_alsa_error ("Creating the output port", output_port);
    }

    client_id = snd_seq_client_id (sequencer);
    printf ("Relay ready: ALSA client %d, input %d, output %d.\n",
            client_id, input_port, output_port);
    puts ("Connect KeyLab Essential MIDI -> KeyLab input, then Ardour's Generic MIDI");
    puts ("Control input <- Ardour output. Press Ctrl-C to stop the relay.");
    fflush (stdout);

    signal (SIGINT, stop);
    signal (SIGTERM, stop);

    while (keep_running) {
        struct snd_seq_event *input_event;
        struct snd_seq_event output_event;

        error_code = snd_seq_event_input (sequencer, &input_event);
        if (error_code == -EINTR) {
            continue;
        }
        if (error_code < 0) {
            fprintf (stderr, "Reading MIDI failed (%d)\n", error_code);
            break;
        }

        /* Subscription/client notifications are not musical MIDI to relay. */
        if (input_event->source.client == client_id ||
            (input_event->type >= SNDRV_SEQ_EVENT_CLIENT_START &&
             input_event->type <= SNDRV_SEQ_EVENT_PORT_UNSUBSCRIBED)) {
            continue;
        }

        output_event = *input_event;
        if (is_keylab_fader_event (&output_event)) {
            int original_value = output_event.data.control.value;
            int scaled_value = scale_keylab_fader_value (original_value);

            output_event.data.control.value = scaled_value;
            if (verbose) {
                fprintf (stderr, "CC %u: %d -> %d\n",
                         output_event.data.control.param,
                         original_value,
                         scaled_value);
            }
        }

        output_event.source.port = (unsigned char) output_port;
        output_event.dest.client = SNDRV_SEQ_ADDRESS_SUBSCRIBERS;
        output_event.dest.port = 0;
        output_event.queue = SNDRV_SEQ_QUEUE_DIRECT;

        error_code = snd_seq_event_output_direct (sequencer, &output_event);
        if (error_code < 0) {
            fprintf (stderr, "Forwarding MIDI failed (%d)\n", error_code);
        }
    }

    snd_seq_close (sequencer);
    return keep_running ? 1 : 0;
}
