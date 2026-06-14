# OnePlus mic trial: gen70-speaker-only-ucm-retrace

## Identity

- UTC time: 20260614T135658Z
- Label: gen70-speaker-only-ucm-retrace
- Mode: pmos-runtime
- Reset note: generation 70 retrace: persistent Mic1 UCM removed and automatic oneplus_bottom_mic source disabled; direct debug route programs bottom mic
- Artifact: /tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z
- Pre-trial git HEAD: 5bdfe5e96b501e7dca9d7121e211bf2b5d89e63c (5bdfe5e96b50)
- Current system: /nix/store/m2kzcfd1nvmwjgrbwxbjsw8214isvf0v-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-70.conf
- Default boot entry: NixOS (Generation 70 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 121.00

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.003815 rms=0.000192 dmesg_lines=2 wav=/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.004486 rms=0.000775 dmesg_lines=1 wav=/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 49919
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 49919
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 50879
/tmp/oneplus-mic-debug-gen70-speaker-only-ucm-retrace-20260614T135658Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 50879
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen70-speaker-only-ucm-retrace' --reset-note 'generation 70 retrace: persistent Mic1 UCM removed and automatic oneplus_bottom_mic source disabled; direct debug route programs bottom mic'
```
