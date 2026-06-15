# OnePlus mic trial: gen72-after-full-poweroff

## Identity

- UTC time: 20260615T033515Z
- Label: gen72-after-full-poweroff
- Mode: pmos-runtime
- Reset note: full power off 30s, immediate post-login, before app source
- Artifact: /tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z
- Pre-trial git HEAD: 881c2a3822264989b0fab605b511294c66dcb756 (881c2a382226)
- Current system: /nix/store/pfl0bc5mar6macksiy1sxxjzihknbarz-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-72.conf
- Default boot entry: NixOS (Generation 72 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-15)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 1082.83

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 51839
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 52799
/tmp/oneplus-mic-debug-gen72-after-full-poweroff-20260615T033515Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 52799
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen72-after-full-poweroff' --reset-note 'full power off 30s, immediate post-login, before app source'
```
