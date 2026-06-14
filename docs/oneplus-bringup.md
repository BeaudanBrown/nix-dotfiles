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

Status: confirmed working. User manually tested with `fftest` and felt both strong and weak rumble effects.

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
- ALSA capture can open on routed `hw:O6T,0` and `hw:O6T,1`, but records exact-zero samples.
- Risky persisted mic/capture UCM route previously caused a failed boot generation and was backed out.
- Reusable live-only debug script, exposed through the flake so dependencies and shell checks are injected by `writeShellApplication`:

```sh
nix run .#debug-oneplus-mic -- /tmp/oneplus-mic-debug-$(date +%s)
```

For a clean reboot comparison that only tests the exact postmarketOS OnePlus/fajita UCM mic routes:

```sh
nix run .#debug-oneplus-mic -- --mode pmos /tmp/oneplus-mic-debug-pmos-$(date +%s)
```

Other focused modes:

```sh
# PMOS SectionVerb-style global backend routes, then each mic path.
nix run .#debug-oneplus-mic -- --mode pmos-global /tmp/oneplus-mic-debug-pmos-global-$(date +%s)

# Exact PMOS routes plus active DAPM snapshots while each capture is open.
nix run .#debug-oneplus-mic -- --mode pmos-dapm /tmp/oneplus-mic-debug-pmos-dapm-$(date +%s)

# Android/OxygenOS mixer_paths_tavil-style routes plus ACDB/blob inventory.
nix run .#debug-oneplus-mic -- --mode android /tmp/oneplus-mic-debug-android-$(date +%s)
```

Direct source script for editing:

```sh
./scripts/debug-oneplus-mic.sh /tmp/oneplus-mic-debug-$(date +%s)
```

The script:

- records ALSA card/PCM/control state,
- sweeps AMIC1-5 through `MultiMedia2` / `SLIMBUS_0_TX` / `AIF1_CAP` / `CDC_IF TX0`,
- captures DAPM snapshots,
- captures WCD934x regmap before/active diffs,
- retries routed `hw:O6T,0`,
- saves WAV/stat/dmesg artifacts,
- resets live capture routes at the end.

Next steps:

- Extend `scripts/debug-oneplus-mic.sh` instead of using one-off shell snippets.
- Continue testing capture routing live only, not persisted, until non-silent capture works.
- Investigate lower-level ADSP/AFE/codec behavior now that DAPM/regmap prove routes power on.
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

Prepared next boot generation:

```text
Generation 56
/nix/store/cd847yabwwdci5v7zi8c2dinz7z88kkk-nixos-system-oneplus-26.05.20260531.b51242d
```

Expected generation 56 runtime changes:

- Persisted speaker gain values in the OnePlus UCM `Speaker` enable sequence:
  - `RX0 Digital Volume = 100`
  - `RX1 Digital Volume = 100`
  - `RX7 Digital Volume = 100`
  - `RX8 Digital Volume = 100`
- Added `scripts/record-oneplus-touch-events.sh` to the repo for manual touch/scroll captures.
- Documentation-only additions for bring-up tracking and confirmed haptics.

Current audio sink on generation 56:

```text
alsa_output.platform-sound.playback.0.0
Built-in Audio [alsa:pcm]
```

Generation 56 audio findings:

- Booted successfully.
- UCM aliases load for `O6T`, `hw:0`, `oneplus-OnePlus6T`, and `sdm845`.
- WirePlumber is not falling back to `Built-in Audio Pro`.
- WirePlumber is deliberately using raw ALSA (`api.alsa.use-acp = false`) with UCM route initialization, so it does not expose a real ACP/UCM `Speaker` profile.
- Persisted speaker gain worked:
  - `RX0 Digital Volume = 100`
  - `RX1 Digital Volume = 100`
  - `RX7 Digital Volume = 100`
  - `RX8 Digital Volume = 100`
- `QUAT_MI2S_RX Audio Mixer MultiMedia1 = on` after boot.
- `spa-acp-tool` probing with ACP/UCM hung during live testing, so ACP should not be re-enabled blindly in a booted generation.

Generation 57 audio findings:

- Booted successfully:
  - `/nix/store/b34y2bxci5f2f4mi0nhwg5yskndc0slk-nixos-system-oneplus-26.05.20260531.b51242d`
- The raw sink rename worked:
  - PipeWire node description: `OnePlus Speaker`
  - PipeWire node nick: `Speaker`
  - Pulse sink description: `OnePlus Speaker`
- Still no Pro Audio fallback in the active runtime path because `api.alsa.use-acp = false` remains set.
- Still not a real ACP/UCM `Speaker` profile; this remains the stable raw ALSA sink with UCM route initialization.
- UCM aliases continue to load for `O6T`, `hw:0`, `oneplus-OnePlus6T`, and `sdm845`.
- Speaker route/gain remains correct after boot:
  - `RX0 Digital Volume = 100`
  - `RX1 Digital Volume = 100`
  - `RX7 Digital Volume = 100`
  - `RX8 Digital Volume = 100`
  - `QUAT_MI2S_RX Audio Mixer MultiMedia1 = on`
- Bounded `spa-acp-tool` probing with `api.alsa.use-acp=true` and UCM enabled initially showed only:
  - `off`
  - `pro-audio`
- Temp UCM variants adding `PlaybackVolume "RX0 Digital Volume"` and `CaptureVolume "ADC2 Volume"` still produced only `off` + `pro-audio`, so missing volume fields were not the reason ACP ignored the UCM profile.
- Root cause found: the `Mic` UCM device used `CapturePCM "hw:O6T,0"`, but ACP reports that PCM as having zero capture channels. That invalid capture device causes ACP to reject the UCM `HiFi` profile.
- A temp speaker-only UCM makes `spa-acp-tool` expose:
  - `off`
  - `HiFi`
  - `pro-audio`
  - port `[Out] Speaker`
  - device `HiFi: Speaker: sink`
- Setting `api.acp.hidden-profiles=pro-audio` makes `spa-acp-tool` select `HiFi` instead of `pro-audio`.
- Next prepared audio change:
  - remove the invalid `Mic` UCM device until a valid capture PCM/route is found
  - map `module/snd_soc_sdm845.conf` to the OnePlus speaker-only UCM
  - set `api.alsa.use-acp = true`
  - keep `api.alsa.use-ucm = true`
  - set `api.acp.hidden-profiles = "pro-audio"`
  - persist RX digital volumes at `120` because YouTube at max volume was still very quiet at `100`
- Prepared as generation 58:
  - `/nix/store/8z290n1y9g7p7izgp7mdv4zcr7kd9v3l-nixos-system-oneplus-26.05.20260531.b51242d`

Post-generation-58 live loudness finding:

- Direct ALSA playback of a 48 kHz stereo S16 test WAV through `hw:O6T,0` was loud.
- The same WAV through PipeWire/`pw-play` was quiet when PipeWire negotiated `s24-32le`.
- A temporary WirePlumber override forcing the sink to `S16LE`, 48 kHz, stereo made PipeWire playback loud.
- Current conclusion: speaker hardware routing/gain is sufficient; the quiet YouTube/PipeWire path is caused by PipeWire's default ALSA format negotiation on this device.
- Next prepared change persists `audio.format = "S16LE"`, `audio.rate = 48000`, and stereo channel layout for both the current raw sink name and the expected ACP/UCM sink using `hw:O6T,0`.

Generation 59 audio findings:

- Booted successfully:
  - `/nix/store/pp1ph7xgmdmj526hjkfyiqschy6wr7jy-nixos-system-oneplus-26.05.20260531.b51242d`
- PipeWire/WirePlumber now exposes the real ACP/UCM speaker sink instead of the raw fallback:
  - `alsa_output.platform-sound.HiFi__Speaker__sink`
  - profile/device: `HiFi: Speaker: sink`
  - port: `[Out] Speaker`
  - object path: `alsa:acp:O6T:0:playback`
  - `api.alsa.open.ucm = true`
- No `Built-in Audio Pro` / Pro Audio fallback is active.
- S16 fix persisted:
  - `s16le 2ch 48000Hz`
  - `audio.format = S16LE`
  - `alsa.resolution_bits = 16`
- UCM for `O6T`, `hw:0`, `oneplus-OnePlus6T`, and `sdm845` loads and now contains only the speaker device. The bad `Mic` capture device remains intentionally removed until a valid capture PCM/route is found.
- Boot restored the new sink volume to 40%, which made output quiet despite the correct sink/profile. Setting the default sink to 100% restored loud PipeWire playback:
  - `wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0`
- No browser/YouTube sink input was active during inspection, so per-app browser volume could not be checked yet.

Mic debugging after generation 59:

- PipeWire intentionally exposes no audio source because the bad UCM `Mic` device was removed to let ACP expose the speaker profile.
- ALSA capture PCMs exist for devices 0-6:
  - `MultiMedia1` through `MultiMedia6`
  - `VoiceMMode1`
- Capture PCMs reject opens until a TX route is enabled.
- `MultiMediaN Mixer SLIMBUS_0_TX = on` maps to capture device `N-1` and opens successfully.
- `TX_CODEC_DMA_TX_*` and `VA_CODEC_DMA_TX_*` mixer routes did not open any MultiMedia capture PCM in live tests.
- Device tree for fajita declares analog mics, not digital mics:
  - `AMIC1`, `AMIC2`, `AMIC3`, `AMIC4`, `AMIC5`
  - corresponding `MIC BIAS*` routes
- Tested live routes that powered the complete DAPM path but still recorded exact zero samples:
  - `MultiMedia2 Mixer SLIMBUS_0_TX = on`
  - `AIF1_CAP Mixer SLIM TX0 = on`
  - `CDC_IF TX0 MUX = DEC0`
  - `ADC MUX0 = AMIC`
  - `AMIC MUX0 = ADC1` with `MIC BIAS3` / `AMIC1` / `ADC1` powered on
  - `AMIC MUX0 = ADC2` with `Headset Mic Switch = on`, `MIC BIAS2` / `AMIC2` / `ADC2` powered on
  - `ADC1/ADC2 Volume = 20`, `DEC0 Volume = 110`
- Also tested `DMIC0..DMIC5`, but DT suggests these are not the relevant fajita mic pins; they also recorded exact zero.
- Tested SLIMBUS capture links 0, 1, and 2 via AIF1/AIF2/AIF3; all opened but recorded exact zero.
- Public downstream/vendor clues found:
  - LineageOS `android_device_oneplus_sdm845-common/audio/mixer_paths_tavil.xml` uses WCD934x/Tavil routes with vendor names like `SLIM_0_TX`, `MultiMedia1 Channel1`, and `IIR0 INP0 MUX`; on mainline many channel controls do not exist, but `IIR0 INP0 MUX` does.
  - postmarketOS `soc-qcom-sdm845` depends on `soc-qcom-sdm845-ucm`; its exact UCM commit includes `ucm2/OnePlus/fajita/HiFi.conf`.
  - postmarketOS fajita UCM says:
    - Bottom mic: `MultiMedia2 <-> SLIMBUS_0_TX`, `AIF1_CAP`, `ADC4`, `TX7`, PCM `hw:${CardId},1`.
    - Top mic: `MultiMedia4 <-> SLIMBUS_1_TX`, `AIF2_CAP`, `ADC3`, `TX6`, PCM `hw:${CardId},3`.
    - Headset mic: `MultiMedia6 <-> SLIMBUS_2_TX`, `AIF3_CAP`, `ADC2`, `TX0`, PCM `hw:${CardId},5`.
  - Exact postmarketOS fajita UCM routes were added to `nix run .#debug-oneplus-mic` and can be run alone with `--mode pmos`; tested in `/tmp/oneplus-mic-debug-pmos-ucm-1`, `/tmp/oneplus-mic-debug-pmos-mode-pre-reboot-2`, and clean-boot `/tmp/oneplus-mic-debug-pmos-clean-1`; all three opened successfully but recorded exact-zero samples with no new dmesg lines/q6 deltas.
  - PMOS SectionVerb-style global backend routes were added as `--mode pmos-global`; `/tmp/oneplus-mic-debug-pmos-global-script-1` still recorded exact-zero for bottom/top/headset.
  - Active DAPM capture snapshots were added as `--mode pmos-dapm`; `/tmp/oneplus-mic-debug-pmos-dapm-script-1` shows each exact PMOS route powers the expected codec path and active AIF capture stream while still recording exact-zero:
    - bottom: `MIC BIAS1` / `AMIC4` / `ADC4` / `ADC MUX7` / `CDC_IF TX7 MUX` / `SLIM TX7` / `AIF1 Capture` on.
    - top: `MIC BIAS4` / `AMIC3` / `ADC3` / `ADC MUX6` / `CDC_IF TX6 MUX` / `SLIM TX6` / `AIF2 Capture` on.
    - headset: `MIC BIAS2` / `AMIC2` / `ADC2` / `ADC MUX0` / `CDC_IF TX0 MUX` / `SLIM TX0` / `AIF3 Capture` on.
  - Manual channel-count probe for the postmarketOS bottom mic route recorded exact-zero samples for `-c1`, `-c2`, and `-c4`; `-c8`/`-c16` were rejected as unavailable.
  - `q6voiced` is a userspace daemon for voice-call hostless PCM activation only; it opens `VoiceMMode1` at S16 mono 8 kHz during calls. It is not currently installed/running here, but q6voice kernel modules are loaded.
  - Clean post-reboot PipeWire/WirePlumber state is good for playback:
    - active profile is `HiFi`, not Pro Audio.
    - Pro Audio is hidden.
    - default sink is `alsa_output.platform-sound.HiFi__Speaker__sink` / `Built-in Audio Speaker playback`.
    - `api.alsa.open.ucm = true`, `api.alsa.path = hw:O6T,0`, format `s16le 2ch 48000Hz`, volume 100%.
    - `alsaucm -c O6T dump text` loads the custom UCM for card id `O6T`.
  - Android/OxygenOS source/artifact inspection:
    - Local Lineage trees are available in `/tmp/oneplus-audio-clues/lineage-fajita` and `/tmp/oneplus-audio-clues/lineage-sdm845-common`.
    - Android routing source is visible in `audio/mixer_paths_tavil.xml`, `audio/audio_platform_info.xml`, and related audio policy XML files.
    - Android proprietary HAL/ACDB loader internals and ADSP firmware internals remain blob-only.
    - Lineage `proprietary-files.txt` lists ACDB calibration files from OxygenOS, including `odm/etc/acdbdata/MTP/MTP_Codec_cal.acdb`, `MTP_Handset_cal.acdb`, `MTP_Headset_cal.acdb`, `MTP_Speaker_cal.acdb`, and common `vendor/etc/acdbdata/adsp_avs_config.acdb`.
    - Current NixOS firmware inventory does not contain those ACDB files; it only shows SDM845 ADSP blobs plus `tfa98xx.cnt.zst` for audio-ish firmware. This makes missing Qualcomm/OnePlus calibration a primary suspect for powered capture paths producing exact-zero samples.
    - Android normal `audio-record` route is `MultiMedia1 Mixer SLIM_0_TX = 1`, which maps to mainline `MultiMedia1 Mixer SLIMBUS_0_TX` / `hw:O6T,0`.
    - Android `handset-mic` and `speaker-mic` route to `amic4`: `AIF1_CAP Mixer SLIM TX0`, `CDC_IF TX0 MUX = DEC0`, `ADC MUX0 = AMIC`, `AMIC MUX0 = ADC4`, `AMIC4_5 SEL = AMIC4`, `IIR0 INP0 MUX = DEC0`.
    - Android `headset-mic` routes to `amic2`: same TX0/DEC0 path with `AMIC MUX0 = ADC2` and headset switch.
    - Added `--mode android` to the mic debugger to test these Android-style routes on the visible mainline frontends and collect ACDB/blob inventory.
    - `--mode android` run `/tmp/oneplus-mic-debug-android-1` confirmed:
      - current firmware at that time still had no ACDB files, only SDM845 ADSP blobs and `tfa98xx.cnt.zst`.
      - Android-style `audio-record`/`MultiMedia1` (`hw:O6T,0`) and cross-check `MultiMedia2` (`hw:O6T,1`) routes all opened.
      - Android `amic4`/`ADC4`, `amic2`/`ADC2`, and `amic3`/`ADC3` paths powered in DAPM as expected (`AIF1 Capture`, `AIF1_CAP Mixer`, `CDC_IF TX0 MUX`, `ADC MUX0`, selected ADC, and mic bias on).
      - all Android-style captures still recorded exact-zero samples with no fresh q6/AFE dmesg.
    - Added local OxygenOS/Lineage audio vendor payload subset as tracked files under `hosts/oneplus/oneplus-fajita/assets/oxygen-audio-vendor/` and copy it into the OnePlus firmware closure under Android-like and firmware-root mirror paths. Contents include MTP ACDB files, `adsp_avs_config.acdb`, Android audio XML/tuning files, and `tfa98xx.cnt`. The larger `lib/rfsa/adsp` binaries and `MTP_workspaceFile.qwsp` from the payload are intentionally omitted from this first low-risk pass. This still only changes the immutable NixOS firmware closure for one generation; it does not write EFS/persist/modem partitions.
    - Post-ACDB boot generation 60 references the new `oneplus-sdm845-firmware-zstd` package; `/run/current-system/firmware/odm` and `/run/current-system/firmware/vendor` are symlinks into it and contain the compressed ACDB/audio files. Initial `fd` checks missed them because they did not follow symlinked subdirectories.
    - Post-ACDB Android route test `/tmp/oneplus-mic-debug-android-acdb-1781433905` still recorded exact-zero samples for Android-style `MultiMedia1`/`hw:O6T,0` and cross-check `MultiMedia2`/`hw:O6T,1` routes using `amic4`, `amic2`, and `amic3`; DAPM snapshots were saved and only one fresh SLIM SAT dmesg line appeared. No `acdb`/`audcal`/loader messages appeared in boot logs, suggesting mainline Linux is not consuming these Android ACDB files by itself.
    - Post-ACDB exact postmarketOS route test `/tmp/oneplus-mic-debug-pmos-acdb-1781434050` confirmed the compressed ACDB/audio files are visible through `/run/current-system/firmware` when following symlinks, but bottom/top/headset PMOS routes still opened and recorded exact-zero samples with no fresh q6/AFE dmesg.
    - Added `--mode tx-codec-dma` to test visible `TX_CODEC_DMA_TX_*` capture frontend mixers as an alternative to SLIMBUS TX. Run `/tmp/oneplus-mic-debug-tx-codec-dma-1781434214` showed `MultiMedia1`/DMA0 and `MultiMedia2`/DMA0..5 all failed to open with `arecord: audio open error: Invalid argument`, so this path is not a hidden working capture route.
    - Added `--mode pmos-params` to sweep PMOS bottom mic route format/rate/channel combinations. Run `/tmp/oneplus-mic-debug-pmos-params-1781434588` tested `S16_LE` and `S24_LE` at 8/16/48 kHz with accepted channel counts; every accepted capture was exact-zero. `S24_3LE` and `S32_LE` were rejected as unsupported; `S24_LE` with 4 channels was rejected as unavailable. This rules out a simple ALSA format/rate/channel mismatch for the known bottom mic route.
    - Added `--mode pmos-runtime` to capture `/proc/asound/card*/pcm*/sub*/hw_params` and active DAPM while PMOS bottom capture runs. Run `/tmp/oneplus-mic-debug-pmos-runtime-1781435024` confirmed `pcm1c` (`MultiMedia2`) reaches `state: RUNNING` with advancing pointers for both `S16_LE` and `S24_LE`, while DAPM shows the complete path on: `AMIC4`/`MIC BIAS1`/`ADC4`/`ADC MUX7`/`AMIC MUX7`/`CDC_IF TX7 MUX`/`SLIM TX7`/`AIF1_CAP` plus ADSP `SLIMBUS_0_TX`/`MultiMedia2 Capture`/`MM_UL2`. Samples still exact-zero and no fresh dmesg.
    - Tested ADC4 over `AIF1_CAP` `SLIM TX0..8` on `MultiMedia2`/`SLIMBUS_0_TX` in `/tmp/oneplus-mic-debug-adc4-tx-slots-1781435268`. TX0..5 opened but all recorded exact-zero. TX6..8 failed at AFE start with `cmd = 0x100e5 returned error = 0x1`, `AFE enable for port 0x4001 failed -22`; after this, even exact PMOS routes in `/tmp/oneplus-mic-debug-pmos-after-adc4-slots-1781435350` failed with the same AFE enable error on SLIMBUS_0/1/2_TX. Treat TX6..8 slot probing as state-poisoning until reboot; the reusable `adc4-tx-slots` mode now skips TX6..8.
    - After manual reboot, `/tmp/oneplus-mic-debug-pmos-reboot-check-1781435750` confirmed the PMOS bottom route recovered and captured non-zero audio: `S16_LE` max `0.089081`, RMS `0.002408`; `S24_LE` max `0.004974`, RMS `0.000565`. The ALSA PCM was `RUNNING`. This proves the bottom mic route works live and the earlier all-zero runs were not a permanent routing limit.
    - Persisted a UCM `Mic` capture device using the proven bottom mic route: `MultiMedia2`/`SLIMBUS_0_TX`, `AIF1_CAP SLIM TX7`, `ADC4`, `hw:O6T,1`, mono capture. Generation 61 showed `alsaucm` parsed this, but PipeWire ACP dropped the HiFi profile and exposed only `off`, leaving PipeWire on Dummy Output.
    - Updated the UCM device to `Mic1` and gave it a low-priority playback side on `hw:O6T,0`, because live `spa-acp-tool` tests showed ACP accepts this duplex-shaped mic block while rejecting capture-only devices in this custom UCM. Speaker remains preferred for playback via higher priority; the mic keeps the proven `hw:O6T,1` capture route.
    - Retrace after generation 62: a fresh boot exposed the UCM Speaker sink and avoided Pro Audio, but did not expose the Mic1 source until later PipeWire restarts/profile changes. A fresh `--mode pmos-runtime` direct ALSA test in `/tmp/oneplus-mic-debug-fresh-gen62-1781439012` again powered the complete bottom mic route and reached `pcm1c` `RUNNING`, but both S16 and S24 captures were exact-zero. To get back to the only known non-zero state, remove the persisted UCM mic device and return to speaker-only UCM before retesting the live PMOS route after reboot.
    - Generation 63 retrace (`/tmp/oneplus-mic-debug-retrace-gen63-1781439461`) used speaker-only UCM again. UCM/WirePlumber exposed the Speaker sink with no Pro Audio fallback, and the PMOS bottom route again powered the same DAPM widgets and reached `pcm1c` `RUNNING`, but samples were still exact-zero. Diffing the generation-60 non-zero artifact against generation 63 showed identical active DAPM and `/proc/asound` runtime state except timestamps/PIDs. The boot entry for exact generation 60 (`/nix/store/0fh3hr1796gfm9gdrpqa22a5dgrcldab-...`) still exists and is the next retrace target.
    - Exact generation 60 retrace (`/tmp/oneplus-mic-debug-retrace-gen60-1781439932`) booted the same system closure that produced the one historical non-zero capture, but it also recorded exact-zero for S16 and S24. ASoC inventory line count and filtered ASoC inventory were identical to the successful run, and active DAPM/proc runtime remained identical except timestamps/PIDs. Therefore the historical non-zero state was not explained by Nix generation, UCM contents, kernel, firmware closure, or visible ALSA/DAPM state. The remaining likely variable is opaque ADSP/SLIM/codec runtime state or reset depth (warm reboot vs full hardware reset).
  - Kernel/channel-map inspection:
    - `sdm845_slim_snd_hw_params()` gets the WCD934x active codec channel map and passes it to q6afe for capture.
    - WCD934x initially has a 16-channel TX map (`128..143`), while q6afe SLIM config has `AFE_MAX_CHAN_COUNT = 8`; `q6slim_set_channel_map()` lacks a bound check, so this is a robustness bug.
    - However WCD934x `get_channel_map()` walks the active DAPM `slim_ch_list`; exact PMOS routes should pass only one active TX slot (`TX7`, `TX6`, or `TX0`), so the 16-channel overflow is probably not hit for these tested routes.
    - q6afe SLIM TX DAI ids are odd (`SLIMBUS_0_TX = 3`, `SLIMBUS_1_TX = 5`, `SLIMBUS_2_TX = 7`), matching `q6slim_set_channel_map()`'s TX branch.
    - q6afe sends only four shared SLIM channel mapping entries to ADSP, but single-channel PMOS routes fit inside that limit.
- Tested `VoiceMMode1` with `VoiceMMode1 Capture Mixer SLIMBUS_0_TX = on`; reads failed with `Invalid argument` at 8/16/32/48 kHz S16 mono.
- During AMIC tests, DAPM showed the whole analog capture path powered on through `AIF1 Capture` and `MultiMedia2 Capture`, but the resulting WAV files had:
  - `Maximum amplitude: 0.000000`
  - `RMS amplitude: 0.000000`
- Current conclusion: routing to the ALSA capture frontend works and powers the codec path, but the stream is filled with zeros. This looks lower than UCM/PipeWire now: likely ADSP/AFE port behavior, codec capture path quirk, or missing downstream kernel/DT routing detail.
- Latest reusable flake-script run:
  - command: `nix run .#debug-oneplus-mic -- /tmp/oneplus-mic-debug-pre-reboot-1`
  - output directory: `/tmp/oneplus-mic-debug-pre-reboot-1`
  - booted system: `/nix/store/pp1ph7xgmdmj526hjkfyiqschy6wr7jy-nixos-system-oneplus-26.05.20260531.b51242d`
  - `writeShellApplication` build/shellcheck passed after using system `/run/wrappers/bin/sudo` instead of injecting non-setuid `pkgs.sudo`.
  - Tracefs exists at `/sys/kernel/tracing`.
  - Available useful trace event group: `regmap`.
  - Missing trace event groups on this kernel: `snd_soc`, `qcom_slim_ngd`, `q6afe`, `q6asm`.
  - Firmware inventory currently has no `/lib/firmware`; active root is `/run/current-system/firmware -> /nix/store/yxvki3a8qlkdm08ndr33qsp9092ggn5f-firmware/lib/firmware`.
  - Audio-ish firmware files found include generic SDM845 ADSP/modem blobs and `tfa98xx.cnt.zst`; no obvious ACDB/calibration/mixer-path files were found by the script inventory.
  - AMIC1/2/2+Headset/3/4/5 each recorded 144000 samples and all had `Maximum amplitude: 0.000000`, `RMS amplitude: 0.000000`.
  - No new dmesg lines appeared during those AMIC sweeps.
  - MultiMedia frontend sweep with AMIC1 via `SLIMBUS_0_TX`:
    - `MultiMedia1`/`hw:O6T,0` through `MultiMedia6`/`hw:O6T,5` all opened and recorded 96000 samples.
    - all were exact-zero samples.
  - TX slot sweep with `MultiMedia2` + `AIF1_CAP` + AMIC1:
    - `SLIM TX0`, `SLIM TX1`, `SLIM TX2`, and `SLIM TX3` all opened and recorded exact-zero samples.
  - SLIMBUS link sweep with `MultiMedia2` + AMIC1:
    - `SLIMBUS_0_TX`/`AIF1_CAP`, `SLIMBUS_1_TX`/`AIF2_CAP`, and `SLIMBUS_2_TX`/`AIF3_CAP` all opened and recorded exact-zero samples.
  - Exact postmarketOS fajita UCM route sweep (`/tmp/oneplus-mic-debug-pmos-ucm-1`):
    - bottom mic: `MultiMedia2`/`SLIMBUS_0_TX`/`AIF1_CAP SLIM TX7`/`ADC4` -> exact-zero.
    - top mic: `MultiMedia4`/`SLIMBUS_1_TX`/`AIF2_CAP SLIM TX6`/`ADC3` -> exact-zero.
    - headset mic: `MultiMedia6`/`SLIMBUS_2_TX`/`AIF3_CAP SLIM TX0`/`ADC2` -> exact-zero.
  - `VoiceMMode1` / `hw:O6T,6` still failed on read with `Invalid argument` at 8/16/32/48 kHz S16 mono.
  - DAPM snapshots are saved correctly by the script.
  - WCD934x regmap diff is saved correctly by the script; active AMIC1 capture changed codec registers including `060e`, `0625`, `0800`, and `0a31`, confirming the codec route is not purely inert.
  - Regmap ftrace around an AMIC1 capture produced 346 trace lines while the WAV remained exact-zero; WCD934x writes include the already-seen capture path registers (`0625`, `0800`, `0a31`, `0a34`, `060e`).
  - Routed `hw:O6T,0` can open if `MultiMedia1 Mixer SLIMBUS_0_TX` is enabled, but its output is also exact-zero samples.
  - Boot log has no obvious `acdb`/`calib` messages in the filtered output; notable boot messages include WCD934x MBHC threshold DT warnings, SoundWire DIN-port mismatch, and one SLIM QMI wait timeout.
- After testing, live capture mixer routes were reset to off to avoid persisting an unsafe state.

Current card:

```text
ALSA card id: O6T
ALSA long card name: oneplus-OnePlus6T
```
