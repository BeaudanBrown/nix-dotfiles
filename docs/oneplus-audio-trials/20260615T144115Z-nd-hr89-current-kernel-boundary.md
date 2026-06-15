# OnePlus mic trial: nd-hr89-current-kernel-boundary

## Identity

- UTC time: 20260615T144115Z
- Label: nd-hr89-current-kernel-boundary
- Mode: pmos-runtime
- Reset note: nd-hr89 current boot retrace before closing as kernel/ADSP work; speaker-only UCM, no static source
- Artifact: /tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z
- Pre-trial git HEAD: ca596e870c9517005a234fa6703e8383d5cf6043 (ca596e870c95)
- Current system: /nix/store/sr5cs5ac1j2ah543nrj6fsvcrha5hz71-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-74.conf
- Default boot entry: NixOS (Generation 75 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-15)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: 8a6665923c01e8df19c554a5f5447eb4ae3c78ff8b18d022e542f52751c09388
- Uptime before trial seconds: 4520.37

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 51839
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 53759
/tmp/oneplus-mic-debug-nd-hr89-current-kernel-boundary-20260615T144115Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 52799
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'nd-hr89-current-kernel-boundary' --reset-note 'nd-hr89 current boot retrace before closing as kernel/ADSP work; speaker-only UCM, no static source'
```
