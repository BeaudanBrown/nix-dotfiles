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
scripts/oneplus-audio-readings.sh --seconds 1 --route-bottom-mic --outdir /tmp/oneplus-audio-readings-nd-ihy2-routed
```

Observed summary:

```text
speaker-monitor  alsa_output.platform-sound.HiFi__Speaker__sink.monitor  positive  samples=96000  max=0.11999878  rms=0.07627125
alsa-capture     hw:0,0..hw:0,6                                         fail      audio open error: Invalid argument before explicit routing
pipewire-source  oneplus_bottom_mic_trial                                zero      samples=48000  max=0.00000000  rms=0.00000000
alsa-capture     hw:O6T,1                                                zero      samples=48000  max=0.00000000  rms=0.00000000
```

Conclusion: userspace can repeatedly produce positive speaker playback monitor readings without regressing the stable speaker path. The current AMIC4/ADC4 bottom-mic route opens and records through both the transient PipeWire source and ALSA `hw:O6T,1`, but all samples are exact zero in this runtime. No kernel compile, patch, or switch was used.
