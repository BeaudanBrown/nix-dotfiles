# OnePlus mic trial: gen69-speaker-and-app-mic

## Identity

- UTC time: 20260614T134323Z
- Label: gen69-speaker-and-app-mic
- Mode: pmos-runtime
- Reset note: generation 69 boot: Speaker UCM sink selected and explicit oneplus_bottom_mic default source present
- Artifact: /tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z
- Pre-trial git HEAD: d86c5f158ae3828711dba3886a7df11632d99bbe (d86c5f158ae3)
- Current system: /nix/store/daz6lkim632kckiyfmg7v5iknvlfilg3-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-69.conf
- Default boot entry: NixOS (Generation 69 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: efa7ae750fd04087b731dc55ecbf4debea1f37392e5fa04c979cf2400bf70032
- Uptime before trial seconds: 121.31

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=1 wav=/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 49919
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 49919
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 52799
/tmp/oneplus-mic-debug-gen69-speaker-and-app-mic-20260614T134323Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 52799
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen69-speaker-and-app-mic' --reset-note 'generation 69 boot: Speaker UCM sink selected and explicit oneplus_bottom_mic default source present'
```
