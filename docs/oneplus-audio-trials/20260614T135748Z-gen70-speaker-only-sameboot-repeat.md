# OnePlus mic trial: gen70-speaker-only-sameboot-repeat

## Identity

- UTC time: 20260614T135748Z
- Label: gen70-speaker-only-sameboot-repeat
- Mode: pmos-runtime
- Reset note: same boot repeat after gen70 speaker-only UCM retrace restored non-zero capture
- Artifact: /tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z
- Pre-trial git HEAD: 8d72f263dcd10727b1a0bce2b9a4b26350bdbdf0 (8d72f263dcd1)
- Current system: /nix/store/m2kzcfd1nvmwjgrbwxbjsw8214isvf0v-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-70.conf
- Default boot entry: NixOS (Generation 70 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 170.79

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.005249 rms=0.000195 dmesg_lines=2 wav=/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.004303 rms=0.000185 dmesg_lines=1 wav=/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 51839
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-gen70-speaker-only-sameboot-repeat-20260614T135748Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 51839
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen70-speaker-only-sameboot-repeat' --reset-note 'same boot repeat after gen70 speaker-only UCM retrace restored non-zero capture'
```
