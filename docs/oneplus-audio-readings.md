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
