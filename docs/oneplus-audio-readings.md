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

## 2026-06-16 mixer-control audit (`nd-zthm`)

Current runtime artifacts were written to `/tmp/oneplus-mixer-nd-zthm-20260616T123432Z`. The audit saved `amixer -c O6T contents` before changes, filtered capture-related controls, a focused selected-control snapshot before/after, an `alsactl` state file, bounded one-second `arecord -D hw:O6T,1` WAVs for each mixer delta, and a final `oneplus-audio-readings.sh --seconds 1 --route-bottom-mic` speaker/mic check. The changes were runtime-only and restored to the saved ALSA state after the trial; `alsactl restore` warned only on read-only impedance/type controls.

Relevant capture controls found in the mixer include the `MultiMedia* Mixer SLIMBUS_*_TX` frontend switches, `AIF*_CAP Mixer SLIM TX*` switches, `CDC_IF TX* MUX` DEC selectors, `ADC MUX*` AMIC/DMIC selectors, `AMIC MUX*` ADC selectors, `AMIC4_5 SEL`, `DMIC MUX*`, and `ADC*`/`DEC* Volume` gains. No separate MICBIAS/MIC BIAS ALSA control was exposed by the current mixer dump.

Trial summary, one-second S16_LE 48 kHz mono through `hw:O6T,1`:

| Trial | Result | Reading | Notes |
| --- | --- | --- | --- |
| Baseline current runtime route | zero | 48,000 samples, max `0.00000000`, RMS `0.00000000` | Pre-existing TX7/TX0-ish mixer state before the trial. |
| TX7/DEC7/ADC4 high gain | positive | 48,000 samples, max `1.00003052`, RMS `0.01858446` | `MultiMedia2 Mixer SLIMBUS_0_TX=on`, `AIF1_CAP Mixer SLIM TX7=on`, `CDC_IF TX7 MUX=DEC7`, `ADC MUX7=AMIC`, `AMIC MUX7=ADC4`, `AMIC4_5 SEL=AMIC4`, `ADC4 Volume=20`, `DEC7 Volume=110`. This clips/raises floor enough to prove the path can emit non-zero samples, but does not yet prove useful voice capture. |
| TX7/DEC7/ADC4 with AMIC5 selector | positive | 48,000 samples, max `0.11578722`, RMS `0.01049874` | Same route with `AMIC4_5 SEL=AMIC5`; lower but non-zero. |
| TX0/DEC0/ADC4 high gain | positive | 48,000 samples, max `1.00003052`, RMS `0.01987934` | Older debug/PMOS-style `SLIM TX0`/`DEC0` variant with `ADC4 Volume=20`, `DEC0 Volume=110`. |
| TX0/DEC0/DMIC0 | positive | 48,000 samples, max `0.00820948`, RMS `0.00019112` | Digital-mic selector emits only a very low-level non-zero signal; not identified as bottom mic. |

The post-trial speaker check remained positive (`speaker-monitor` max `0.11999878`, RMS `0.07627125`), while the helper's conservative known AMIC4/ADC4 route (`ADC4 Volume=12`, `DEC7 Volume=84`) still recorded exact zero through both ALSA and the transient PipeWire source. Conclusion: the exact-zero state is at least partly mixer/gain sensitive. High-gain ADC4/TX0 or TX7 routes can produce non-zero samples without breaking speaker playback, but they may be clipped/noise-only; the next ticket should compare these deltas against UCM/vendor routes before making any persistent route change.
