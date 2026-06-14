# OnePlus mic trial: sameboot-repeat-pmos-runtime

## Identity

- UTC time: 20260614T124329Z
- Label: sameboot-repeat-pmos-runtime
- Mode: pmos-runtime
- Reset note: same boot immediately after coldboot-pmos-runtime non-zero result; routes were reset by previous trial
- Artifact: /tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z
- Pre-trial git HEAD: 19c4918f09a522c3a7dbefef537747ffe45f0381 (19c4918f09a5)
- Current system: /nix/store/m2kzcfd1nvmwjgrbwxbjsw8214isvf0v-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-63.conf
- Default boot entry: NixOS (Generation 63 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 189.52

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.014252 rms=0.000421 dmesg_lines=1 wav=/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.006073 rms=0.000498 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 51839
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-sameboot-repeat-pmos-runtime-20260614T124329Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 51839
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'sameboot-repeat-pmos-runtime' --reset-note 'same boot immediately after coldboot-pmos-runtime non-zero result; routes were reset by previous trial'
```
