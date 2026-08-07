# Live Keyboard

## KeyLab Essential Cue + Mix map

`keylab-essential-ardour-cue-map` writes an Ardour Cue Grid layout to one of the
six editable User maps on an **original** Arturia KeyLab Essential 49/61/88.
With `--mixer-controls`, it also writes a banked mixer layout. It does not
change the read-only Analog Lab or DAW maps.

The generated pad layout is deliberately separate from the keybed:

| Pads | Type | MIDI channel | Notes | Hardware behaviour |
| --- | --- | --- | --- | --- |
| 1-8 | MIDI Note | 16 | 36-43 (C1-G1) | Gate; fixed on velocity 127, off velocity 0 |

Ardour can then MIDI-learn the eight notes as Cue triggers. Keep the keybed on
channel 1 and configure MIDI instrument tracks to record only channel 1, so
pad presses do not play or record instrument notes.

The optional mixer-control layout uses channel 16 as well, but emits CCs rather
than notes, so it is distinct from both the keybed and the Cue pads.

| Control | MIDI event | Ardour binding in the supplied map |
| --- | --- | --- |
| Faders 1-8 | CC 20-27; physical-up = 127 | Gain for banked strips B1-B8 |
| Fader 9 | CC 28; physical-up = 127 | Master gain |
| Knobs 1-8 | CC 70-77 | Pan direction for B1-B8 |
| Knob 9 | CC 78 | First send on the selected strip, e.g. an FX send |
| Part 1 | Note 44, Gate | Previous bank |
| Part 2 | Note 45, Gate | Next bank |
| Live | Note 46, Gate | Toggle Ardour's global record arm |

### Apply it

List the hardware ports, then use the `KeyLab Essential MIDI` raw-MIDI output
port rather than `MIDIIN2` (the MCU/HUI port):

```sh
./keylab-essential-ardour-cue-map --list-ports
./keylab-essential-ardour-cue-map --port hw:2,0,0 --map 1 --mixer-controls
```

`--map` accepts `1` through `6` and defaults to `1`. The chosen map is named
`Ardour Cue`, overwritten, committed to the controller, and selected when the
command finishes. Use `--dry-run` to inspect the SysEx messages first, or
`--no-select` to skip target-map activation. Normal operation deliberately
recalls the target User map before and after writing, which is more reliable on
the legacy Essential.

Use `--mixer-controls` for a reliable full User-map initialization. On the
legacy Essential, isolated controller-only writes can be ignored, so
`--controls-only` is retained only as a compatibility alias and also rewrites
the known-good pad definitions.

Preview a fresh full layout without writing hardware:

```sh
./keylab-essential-ardour-cue-map --port hw:2,0,0 --map 1 --mixer-controls --dry-run
```

The script relies only on `amidi` from `alsa-utils`, which is normally available
on Fedora. It spaces messages by 20 ms, gives each flash store a further 80 ms,
and explicitly stores the User map after each change. A full map write takes
roughly 25 seconds; this avoids sporadically dropped parameter writes on the
legacy Essential. The fader Min/Max values are deliberately `127`/`0`: this
compensates for the original Essential's observed physical polarity so that
moving a fader up increases the Ardour value.

### Full-range fader scaling

The original Essential may still report `1`, rather than `0`, at a physical
fader's lowest endpoint. The supplied Generic MIDI map has no value-transform
field, so use the optional relay to rescale each fader's observed `1`-`127`
range across MIDI's full `0`-`127` range (for example, to make a fader fully
mute a strip):

```sh
make
./keylab-essential-ardour-cc-floor
```

The relay creates **KeyLab input** and **Ardour output** ports. In qpwgraph,
disconnect the normal KeyLab port from Ardour's Generic MIDI Control input,
then connect **KeyLab Essential MIDI -> KeyLab input** and **Ardour output ->
Ardour Generic MIDI Control**. Use the relay output instead of the direct
KeyLab port for any Cue-trigger input too. It changes only channel-16 CC
20-28 values from the controller's `1`-`127` fader range to `0`-`127`; all
other MIDI, including pad notes, keybed notes, knobs, and buttons, passes
through unchanged. Leave the relay running while performing.

### Install the Ardour binding map

Copy [`ardour-keylab-essential-cue-mix.map`](ardour-keylab-essential-cue-mix.map)
to Ardour's user `midi_maps` directory, then restart Ardour:

```sh
mkdir -p ~/.config/ardour9/midi_maps
cp ardour-keylab-essential-cue-mix.map ~/.config/ardour9/midi_maps/
```

If you use a non-standard Ardour configuration directory, use its `midi_maps`
subdirectory instead. In `Edit -> Preferences -> Control Surfaces -> Generic
MIDI`, enable Generic MIDI, select **KeyLab Essential Cue + Mix**, and connect
the normal KeyLab MIDI port to Ardour's Generic MIDI Control input. Part 1 and
Part 2 move the eight-strip bank; the labels written to the faders and knobs
are `Track 1` through `Track 8`, `Master`, `Pan 1` through `Pan 8`, and `FX
Send`. Knob 9 does nothing until the selected strip has a first send; it is
intended for a reverb, delay, or other live FX bus.

The faders and knobs are non-motorised absolute controls. After changing banks,
the first movement can jump a parameter to the control's physical position, so
set their positions before a live transition.

### Ardour side

In Ardour, also select the normal KeyLab MIDI input in `Preferences ->
Triggering`, then right-click each Cue slot, choose **MIDI Learn**, and strike
the matching pad. Cue triggering and Generic MIDI control are separate Ardour
inputs; the supplied map does not bind the pad notes. Set normal loop clips to
`Trigger` launch style, `1 bar` quantization, and `Again` follow action.

### Protocol notes

The script writes User map IDs `03` through `08`. Its pad controller IDs are
`70` through `77`; parameter 1 selects Note mode (`07`), parameter 2 is the
zero-based MIDI channel, parameter 3 is the note number, parameters 4 and 5
are the fixed off/on velocities, and parameter 7 selects Gate (`01`). `F0 … 42
06 MAP F7` commits each change, and the map title is written as an Arturia
string at parameter `20`, control `3F`. The extra controller IDs are knobs
`01` through `09`, faders `42` through `4A`, and Part 1/Part 2/Live `1A`/`1B`/
`1C`. These values match SysEx Controls' original KeyLab Essential
implementation.
