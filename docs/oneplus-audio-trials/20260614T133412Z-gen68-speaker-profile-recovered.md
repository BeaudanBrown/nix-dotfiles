# OnePlus mic trial: gen68-speaker-profile-recovered

## Identity

- UTC time: 20260614T133412Z
- Label: gen68-speaker-profile-recovered
- Mode: pmos-runtime
- Reset note: generation 68 boot loaded explicit oneplus_bottom_mic but ACP selected Mic1; live pactl set-card-profile HiFi Speaker restored Speaker sink before trial
- Artifact: /tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z
- Pre-trial git HEAD: 7e283d19b55e6a664f5ebb4c8676db7e3cd5ec49 (7e283d19b55e)
- Current system: /nix/store/nl5bnmbjmz2ac3kd8i18x9gg47zzcqps-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-68.conf
- Default boot entry: NixOS (Generation 68 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: efa7ae750fd04087b731dc55ecbf4debea1f37392e5fa04c979cf2400bf70032
- Uptime before trial seconds: 123.25

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=1 wav=/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 49919
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 49919
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 52799
/tmp/oneplus-mic-debug-gen68-speaker-profile-recovered-20260614T133412Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 52799
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen68-speaker-profile-recovered' --reset-note 'generation 68 boot loaded explicit oneplus_bottom_mic but ACP selected Mic1; live pactl set-card-profile HiFi Speaker restored Speaker sink before trial'
```
