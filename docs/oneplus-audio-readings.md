# OnePlus audio readings

Current repeatable non-kernel procedure for `nd-ihy2`:

```sh
nix run .#oneplus-audio-readings -- --seconds 2
nix run .#oneplus-audio-readings -- --seconds 2 --route-bottom-mic
```

The default run records the current speaker sink monitor plus every currently visible ALSA/PipeWire capture source without changing mixer routing. `--route-bottom-mic` is an explicit reversible trial: it applies the AMIC4/ADC4 bottom-mic route, loads a transient `oneplus_bottom_mic_trial` PipeWire Pulse source, records it, and unloads that module on exit.

## 2026-06-16 current runtime result

Command run directly from the working tree (same script as the flake app, no kernel/build changes):

```sh
scripts/oneplus-audio-readings.sh --seconds 1 --route-bottom-mic --outdir /tmp/oneplus-audio-readings-nd-iwoo-helper
```

Observed summary:

```text
speaker-monitor  alsa_output.platform-sound.HiFi__Speaker__sink.monitor  positive  samples=96000  max=0.11999878  rms=0.07627125
alsa-capture     hw:0,0                                                  fail      audio open error: Invalid argument before explicit routing
alsa-capture     hw:0,1                                                  zero      samples=48000  max=0.00000000  rms=0.00000000
alsa-capture     hw:0,2..hw:0,6                                          fail      audio open error: Invalid argument before explicit routing
pipewire-source  oneplus_bottom_mic_trial                                zero      samples=48000  max=0.00000000  rms=0.00000000
alsa-capture     hw:O6T,1                                                zero      samples=48000  max=0.00000000  rms=0.00000000
```

`nd-iwoo` measurement validation also repeated the AMIC4/ADC4 route with direct commands outside the helper:

```sh
arecord -q -D hw:O6T,1 -f S16_LE -r 48000 -c 1 -d 2 /tmp/oneplus-mic-validate-nd-iwoo/alsa-s16-48k-2s.wav
arecord -q -D hw:O6T,1 -f S16_LE -r 48000 -c 1 -d 1 /tmp/oneplus-mic-validate-nd-iwoo/alsa-s16-48k-1s.wav
arecord -q -D hw:O6T,1 -f S24_LE -r 48000 -c 1 -d 1 /tmp/oneplus-mic-validate-nd-iwoo/alsa-s24-48k-1s.wav
pw-record --target oneplus_bottom_mic_validate --rate 48000 --channels 1 --format s16 --sample-count 96000 /tmp/oneplus-mic-validate-nd-iwoo/pw-s16-48k-2s-rerun.wav
```

Independent byte/sample inspection of those WAV files found valid-duration captures with `nonzero_bytes=0`, `peak=0`, and `rms=0` for ALSA S16 1 s, ALSA S16 2 s, ALSA S24 1 s (written as 32-bit WAV container), and PipeWire S16 2 s. `arecord -f S32_LE` failed because the device only advertised S16_LE and S24_LE.

Conclusion: userspace can repeatedly produce positive speaker playback monitor readings without regressing the stable speaker path. The current AMIC4/ADC4 bottom-mic route opens and records through both PipeWire and ALSA, but all samples are exact zero across helper analysis, direct commands, two durations, and S16/S24 capture formats in this runtime. Treat the zero as a real capture result, not a helper/WAV-analysis artifact. No kernel compile, patch, persistent route change, or switch was used.

## 2026-06-16 ALSA/PipeWire capture matrix (`nd-h6lz`)

Current enumeration artifacts were written to `/tmp/oneplus-capture-matrix-nd-h6lz-20260616T123012Z` and routed-helper artifacts to `/tmp/oneplus-audio-readings-nd-h6lz-route`. Commands used current runtime tools only (`arecord -l/-L`, `pactl list sources short`, `wpctl status`, `pw-cli ls Node`, bounded one-second `arecord`/`pw-record`, and `scripts/oneplus-audio-readings.sh --seconds 1 --route-bottom-mic`). No Nix build, kernel change, persistent config change, or reboot was used.

Visible endpoints:

- ALSA hardware capture devices: `hw:0,0` through `hw:0,6` (`O6T` / OnePlus 6T: `MultiMedia1`..`MultiMedia6`, `VoiceMMode1`).
- ALSA named PCMs from `arecord -L`: `null`, `pipewire`, `default`, `sysdefault:CARD=O6T`.
- PipeWire/Pulse audio sources from `pactl list sources short`: only `alsa_output.platform-sound.HiFi__Speaker__sink.monitor`; `wpctl status` showed no audio Sources, while the default configured source still named stale `oneplus_bottom_mic`.
- A transient routed source, `oneplus_bottom_mic_trial`, was loaded only during the explicit AMIC4/ADC4 bottom-mic helper run and unloaded on exit.

Matrix summary, one-second S16_LE 48 kHz mono unless noted:

| Layer | Endpoint | Result | Evidence |
| --- | --- | --- | --- |
| ALSA | `hw:0,0` / `MultiMedia1` | error | `audio open error: Invalid argument` |
| ALSA | `hw:0,1` / `MultiMedia2` | zero | 48,000 samples, max `0.00000000`, RMS `0.00000000` |
| ALSA | `hw:0,2`..`hw:0,6` | error | each failed with `audio open error: Invalid argument` |
| ALSA | `plughw:0,0` | error | `audio open error: Invalid argument` |
| ALSA | `plughw:0,1` | zero | 48,000 samples, max `0.00000000`, RMS `0.00000000` |
| ALSA | `plughw:0,2`..`plughw:0,6` | error | each failed with `audio open error: Invalid argument` |
| ALSA | `sysdefault:CARD=O6T` | error | `audio open error: Invalid argument` |
| ALSA | `default` / `pipewire` | error | PipeWire ALSA PCM rejected requested capture hw params in this no-audio-source state |
| ALSA | `null` | non-mic/generated | Opened and produced non-zero synthetic samples; not an internal microphone route |
| PipeWire | `alsa_output.platform-sound.HiFi__Speaker__sink.monitor` | error in direct mic matrix; positive in helper speaker probe | Direct `pw-record --target ...monitor` reported `no target node available`; the helper simultaneously played a 440 Hz probe and captured the same monitor as positive (`max 0.11999878`, RMS `0.07525060`) |
| PipeWire transient | `oneplus_bottom_mic_trial` after AMIC4/ADC4 route | zero | 48,000 samples, max `0.00000000`, RMS `0.00000000` |
| ALSA routed | `hw:O6T,1` after AMIC4/ADC4 route | zero | 48,000 samples, max `0.00000000`, RMS `0.00000000` |

Conclusion: this runtime has no visible ALSA or PipeWire internal microphone endpoint that returns non-zero samples. The only positive readings are the speaker monitor probe and ALSA `null`'s generated data, neither of which is an internal microphone. The only microphone-like device that opens is `MultiMedia2` (`hw:0,1` / `plughw:0,1` / `hw:O6T,1` after explicit routing), and it remains exact-zero through both ALSA and a transient PipeWire source. The next useful non-kernel touchpoint is mixer-control inspection (`nd-zthm`) rather than more endpoint enumeration.
