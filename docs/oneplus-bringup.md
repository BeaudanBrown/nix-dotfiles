# OnePlus 6T Bring-up Log

Persistent working record for the `oneplus` / OnePlus 6T (`fajita`) NixOS bring-up.

## Goals

- Make core phone hardware usable under NixOS.
- Keep a durable record of working commands, known failures, and fixes.
- Track what has been completed vs. what still needs investigation.

## Completed

### Boot/rebuild workflow

- Added tracked `./rebuild` script for OnePlus boot-generation iteration.
- Updated `nr` alias to use the same boot-generation flow.
- Established workflow: commit coherent changes before `nr`; do not run `nix eval` immediately before `nr`.
- Added generic Pi boot-resume workflow:
  - `.pi/boot-system.md`
  - ignored `.pi/boot-task.md`
  - `scripts/pi-boot-resume.sh`
  - `scripts/pi-boot-seed.sh`
  - `docs/pi-boot-resume.md`

### Temporary debug access

- Enabled temporary full passwordless sudo for `wheel` on OnePlus:
  - `security.sudo.wheelNeedsPassword = false;`
- Remove this once the phone is stable overall.

### Audio playback

- Renamed audio module root from `main.nix` to `client.nix` so it applies to the OnePlus roots.
- Added custom OnePlus 6T UCM profile in `hosts/oneplus/oneplus-fajita/system.nix`.
- Added UCM aliases for:
  - `O6T`
  - `oneplus-OnePlus6T`
  - `sdm845`
- Confirmed custom UCM loads with `alsaucm -c O6T dump text`.
- Confirmed TFA speaker amp probes successfully:
  - `tfa98xx 4-0034: TFA9894 detected`
  - `tfa98xx 4-0034: Probe completed successfully`
- Found working audible speaker route:
  - `QUAT_MI2S_RX Audio Mixer MultiMedia1 = on`
- Current supported PipeWire path uses raw ALSA instead of ACP/Pro Audio:
  - `api.alsa.use-acp = false`
  - `api.alsa.use-ucm = true`
  - `api.alsa.split-enable = false`
- Added `oneplus-audio-route.service` before WirePlumber:
  - `alsaucm -c O6T set _verb HiFi set _enadev Speaker`
- Suppressed invalid raw ALSA nodes:
  - `alsa_input.platform-sound.capture.*`
  - `alsa_output.platform-sound.playback.[1-6].*`
- Added `node.link-group = "oneplus-speaker"` so ashell sees the raw sink.
- Persisted speaker gain values after loud noise test was audibly loud:
  - `RX0 Digital Volume = 100`
  - `RX1 Digital Volume = 100`
  - `RX7 Digital Volume = 100`
  - `RX8 Digital Volume = 100`

### Squeekboard

- Removed custom terminal `>_` / actions key without widening the space key.
- Custom layout path:
  - `hosts/oneplus/oneplus-fajita/ui/squeekboard-keyboards/terminal/us.yaml`
- Installed via Home Manager to:
  - `~/.local/share/squeekboard/keyboards/terminal/us.yaml`
- Validated with `squeekboard-test-layout`.

### Touch/tmux debugging support

- Fixed invalid tmux wheel binding syntax after error:
  - `command copy-mode: too many arguments`
- Added `scripts/record-oneplus-touch-events.sh` to capture:
  - libinput events
  - raw evdev events
  - terminal input bytes
  - Wayland `wev` events when possible
- Current observation: live captures during chat saw no raw touch events, so further capture must be run manually while swiping outside the chat flow.

## Known Working Commands

### Speaker route / playback

```sh
alsaucm -c O6T set _verb HiFi set _enadev Speaker
amixer -c O6T cset name="QUAT_MI2S_RX Audio Mixer MultiMedia1" 1
speaker-test -D hw:O6T,0 -c 2 -t sine -f 1000 -l 1
```

Check current speaker gain:

```sh
for c in \
  'RX0 Digital Volume' \
  'RX1 Digital Volume' \
  'RX7 Digital Volume' \
  'RX8 Digital Volume' \
  'QUAT_MI2S_RX Audio Mixer MultiMedia1'; do
  echo "--- $c"
  amixer -c O6T cget name="$c"
done
```

Current default PipeWire/Pulse sink should be:

```sh
pactl get-default-sink
# alsa_output.platform-sound.playback.0.0
```

### Touch/scroll capture

Run outside chat, then swipe in Ghostty/tmux and any opened `wev` window:

```sh
./scripts/record-oneplus-touch-events.sh 45
cat /tmp/oneplus-touch-events-*/summary.txt
```

### Haptics

Haptics device is present:

```sh
/dev/input/by-path/platform-c440000.spmi-platform-c440000.spmi:pmic@3:haptics@c000-event
```

Kernel registers it as:

```text
input: spmi_haptics as .../pmic@3:haptics@c000/input/input4
```

`fftest` can open it with sudo and upload force-feedback effects successfully:

```text
Force feedback effects types: Periodic, Rumble, Gain
Force feedback periodic effects: Square, Triangle, Sine
Number of simultaneous effects: 16
Uploading effect #0 (Periodic sinusoidal) ... OK
Uploading effect #4 (Strong rumble, with heavy motor) ... OK
Uploading effect #5 (Weak rumble, with light motor) ... OK
```

Manual test:

```sh
sudo fftest /dev/input/by-path/platform-c440000.spmi-platform-c440000.spmi:pmic@3:haptics@c000-event
```

Status: kernel side looks functional; user confirmation needed for whether the test is physically felt.

### Camera flash / torch

Torch LEDs are exposed at:

```sh
/sys/class/leds/white:flash
/sys/class/leds/yellow:flash
```

Low-brightness torch test:

```sh
echo 20 | sudo tee /sys/class/leds/white:flash/brightness
sleep 2
echo 0 | sudo tee /sys/class/leds/white:flash/brightness
```

Brief strobe test:

```sh
echo 250000 | sudo tee /sys/class/leds/white:flash/flash_brightness
echo 200000 | sudo tee /sys/class/leds/white:flash/flash_timeout
echo 1 | sudo tee /sys/class/leds/white:flash/flash_strobe
cat /sys/class/leds/white:flash/flash_fault
```

Start low; do not test max current for long.

## Open Issues / Planned Fixes

### Audio capture / microphone

Status: blocked.

Findings:

- PipeWire currently exposes no real audio source, only monitor source.
- ALSA capture can open on `hw:O6T,1`, but records silence with tested route.
- Risky persisted mic/capture UCM route previously caused a failed boot generation and was backed out.

Known silent test route:

```text
MultiMedia2 Mixer SLIMBUS_0_TX = on
AMIC MUX0 = ADC2
ADC MUX0 = AMIC
ADC2 Volume = 10
arecord -D hw:O6T,1 -f S16_LE -r 48000 -c 2 -d 2 /tmp/oneplus-mic.wav
```

Next steps:

- Continue testing capture routing live only, not persisted, until non-silent capture works.
- Investigate valid WCD934x TX path and ADC/DMIC/AMIC mapping.
- Expose a PipeWire source only after ALSA capture produces non-silent audio.

### Touch scrolling in tmux/Ghostty

Status: unresolved.

Findings:

- Tmux wheel bindings exist and syntactically validate.
- Finger swipes did not appear as `WheelUpPane`/`WheelDownPane` events in tmux.
- Live libinput/evtest/wev attempts during chat captured no motion events, only device-added output.

Next steps:

- Run `scripts/record-oneplus-touch-events.sh` outside chat.
- Determine whether swipes produce:
  - raw touchscreen evdev events only,
  - Wayland touch events,
  - terminal mouse escape bytes,
  - or Ghostty-internal scrollback only.
- Only then choose a fix.

### Bluetooth / WCN3990

Status: likely broken.

Log evidence:

```text
spmi spmi-0: disallowed SPMI write to sid=0, addr=0xC240
qcom-spmi-gpio c440000.spmi:pmic@0:gpio@c000: write 0x40 failed
pwrseq-qcom_wcn wcn3990-pmu: error -EPERM: Error applying setting, reverse things back
```

User-space symptoms:

```text
BlueZ system service is not available
No local bluetooth adapter found
Cannot find Bluez 5 adapter
```

Next steps:

- Check whether Bluetooth adapter appears with `bluetoothctl list` after boot.
- Investigate WCN3990 power sequencing / PMIC GPIO permissions / device tree.

### Wi-Fi MAC / key-install warnings

Status: partially working, needs investigation.

Log evidence:

```text
ath10k_snoc 18800000.wifi: invalid MAC address; choosing random
ath10k_snoc 18800000.wifi: failed to install key for vdev 0 peer ...: -110
wlan0: failed to remove key ... from hardware (-110)
```

Next steps:

- Determine whether persistent MAC should come from firmware/NVRAM/calibration.
- Watch for reconnect/roaming/encryption failures.

### Camera actuator / OIS

Status: likely broken or partially broken.

Log evidence:

```text
lc898217xc 16-0072: Error writing reg 0x0084: -6
lc898217xc 16-0072: failed to set DAC: -6
lc898217xc 17-0074: Error writing reg 0x0084: -6
lc898217xc 17-0074: failed to set DAC: -6
```

Likely affects optical image stabilization or lens actuator behavior. Camera sensors may still work.

Next steps:

- Test camera enumeration and capture separately.
- Determine whether failures are from power sequencing, regulator, or driver expectations.

### Battery fuel gauge metadata

Status: inaccurate metadata.

Log evidence:

```text
bq27xxx-battery 10-0055: missing battery:energy-full-design-microwatt-hours
bq27xxx-battery 10-0055: invalid battery:energy-full-design-microwatt-hours -22
```

Next steps:

- Check UPower and `/sys/class/power_supply/*` capacity reporting.
- Add/correct design capacity in device tree if needed.

### RTC / time at boot

Status: broken/weak RTC time.

Log evidence:

```text
rtc-pm8xxx ... setting system clock to 1970-01-01...
```

Effects:

- Journal timestamps are confusing.
- Timers report future persistent timestamps.
- KDE Connect certificate appears expired due to bad pre-network time.

Next steps:

- Investigate RTC persistence on this platform.
- Consider boot-time network time handling for services that care about certificates.

### GPU/display firmware/SMMU warnings

Status: GUI works, but logs are noisy.

Log evidence:

```text
msm_dpu ... failed to load a630_sqe.fw
arm-smmu ... Unhandled context fault
```

Later log evidence shows firmware eventually loads from a new location:

```text
[drm:adreno_request_fw] loaded qcom/a630_sqe.fw from new location
[drm:adreno_request_fw] loaded qcom/a630_gmu.bin from new location
```

Next steps:

- Treat as lower priority unless GPU/display instability appears.
- Confirm firmware paths are correct in the final generation.

### Audio codec topology warnings

Status: related to ongoing audio work.

Log evidence:

```text
wcd934x-codec ... ASoC: mux ... has no paths
qcom-soundwire ... din-ports (2) mismatch with controller (6)
qcom,slim-ngd-ctrl ... QMI wait timeout
MultiMedia1: ASoC: no backend DAIs enabled for MultiMedia1
```

Next steps:

- Continue using known-good raw ALSA playback path.
- Revisit ACP/UCM only after routes are understood.

### hexagonrpcd service unit typo

Status: simple config bug.

Log evidence:

```text
hexagonrpcd-adsp-sensorspd.service: Unknown key 'ConditionPathExists' in section [Service]
```

Next steps:

- Move `ConditionPathExists` entries to `[Unit]` if this unit is generated by our config.

## Failed / Risky Changes

### Persisted mic/capture route and playback gain in UCM

A previous attempt to persist mic/capture routing and speaker gain caused generation 53 to fail boot. It was backed out.

Known failed generation:

```text
Generation 53
/nix/store/2qzlpjhsbpicxlj8059531sgdy0qw84h-nixos-system-oneplus-26.05.20260531.b51242d
```

Avoid persisting capture route changes until they have been proven safe live.

## Useful Current State

Known successful boot generation during this bring-up:

```text
Generation 55
/nix/store/4wz6myn0xqax5828dh4xbffvhll0f0h8-nixos-system-oneplus-26.05.20260531.b51242d
```

Current audio sink:

```text
alsa_output.platform-sound.playback.0.0
Built-in Audio [alsa:pcm]
```

Current card:

```text
ALSA card id: O6T
ALSA long card name: oneplus-OnePlus6T
```
