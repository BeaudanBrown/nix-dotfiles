# OnePlus mic trial: gen71-manual-source-boot-zero

## Identity

- UTC time: 20260615T004323Z
- Label: gen71-manual-source-boot-zero
- Mode: pmos-runtime
- Reset note: generation 71 boot: speaker-only UCM plus automatic manual-route oneplus_bottom_mic source present; app-source and direct hw1 spot checks were exact-zero before this trial; tree dirty only from pi boot-resume files
- Artifact: /tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z
- Pre-trial git HEAD: d3860123e8c493484b5e845432d1bdbfb7bd55df (d3860123e8c4)
- Current system: /nix/store/kisc6zk9c8p99hpz7a1g3bqkapw65vfm-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-71.conf
- Default boot entry: NixOS (Generation 71 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-15)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 208.14

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 51839
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 52799
/tmp/oneplus-mic-debug-gen71-manual-source-boot-zero-20260615T004323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 52799
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen71-manual-source-boot-zero' --reset-note 'generation 71 boot: speaker-only UCM plus automatic manual-route oneplus_bottom_mic source present; app-source and direct hw1 spot checks were exact-zero before this trial; tree dirty only from pi boot-resume files'
```
