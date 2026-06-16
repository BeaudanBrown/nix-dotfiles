# OnePlus mic trial: gen66-restore-ucm-mic

## Identity

- UTC time: 20260614T131419Z
- Label: gen66-restore-ucm-mic
- Mode: pmos-runtime
- Reset note: generation 66 restored after failed static PipeWire source; UCM Mic1 visible; PipeWire speaker sink only
- Artifact: /tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z
- Pre-trial git HEAD: 7e5de10e621c0030010bf83e04f7c21be164a3cb (7e5de10e621c)
- Current system: /nix/store/vh0s4ks75r3h35mkii4i5im55j05n7ry-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-66.conf
- Default boot entry: NixOS (Generation 66 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: efa7ae750fd04087b731dc55ecbf4debea1f37392e5fa04c979cf2400bf70032
- Uptime before trial seconds: 122.33

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 51839
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 52799
/tmp/oneplus-mic-debug-gen66-restore-ucm-mic-20260614T131419Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 52799
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen66-restore-ucm-mic' --reset-note 'generation 66 restored after failed static PipeWire source; UCM Mic1 visible; PipeWire speaker sink only'
```
