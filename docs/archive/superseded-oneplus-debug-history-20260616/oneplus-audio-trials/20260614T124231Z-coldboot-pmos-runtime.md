# OnePlus mic trial: coldboot-pmos-runtime

## Identity

- UTC time: 20260614T124231Z
- Label: coldboot-pmos-runtime
- Mode: pmos-runtime
- Reset note: full power off/cold boot, immediate post-login run after checking PipeWire UCM speaker state
- Artifact: /tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z
- Pre-trial git HEAD: c3a3036a24c2da0f927becf0c7f8a65d85caff08 (c3a3036a24c2)
- Current system: /nix/store/m2kzcfd1nvmwjgrbwxbjsw8214isvf0v-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-63.conf
- Default boot entry: NixOS (Generation 63 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 131.09

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.005920 rms=0.000826 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.004486 rms=0.000360 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 49919
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 49919
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 50879
/tmp/oneplus-mic-debug-coldboot-pmos-runtime-20260614T124231Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 50879
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'coldboot-pmos-runtime' --reset-note 'full power off/cold boot, immediate post-login run after checking PipeWire UCM speaker state'
```
