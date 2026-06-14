# OnePlus mic trial: gen64-coldboot-ucm-mic

## Identity

- UTC time: 20260614T125257Z
- Label: gen64-coldboot-ucm-mic
- Mode: pmos-runtime
- Reset note: generation 64 cold boot with ACP-compatible Mic1 UCM visible in alsaucm; PipeWire initially exposes speaker sink but no mic source
- Artifact: /tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z
- Pre-trial git HEAD: 19376e9f7f24bff42c10c95fa42a86d789a83969 (19376e9f7f24)
- Current system: /nix/store/vh0s4ks75r3h35mkii4i5im55j05n7ry-nixos-system-oneplus-26.05.20260531.b51242d
- Current boot entry: nixos-generation-64.conf
- Default boot entry: NixOS (Generation 64 NixOS Yarara 26.05.20260531.b51242d (Linux 7.0.0-next-20260414-sdm845), built on 2026-06-14)
- Firmware path: /nix/store/cpxxb3mm1a4qg8qfg6lkqq015saszm6c-firmware/lib/firmware
- UCM dump sha256: efa7ae750fd04087b731dc55ecbf4debea1f37392e5fa04c979cf2400bf70032
- Uptime before trial seconds: 127.76

## Result summary

```text
pmos_runtime_bottom_s16_48k_1ch dev=1 format=S16_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch.wav
pmos_runtime_bottom_s24_48k_1ch dev=1 format=S24_LE rate=48000 channels=1 code=0 samples=240000 max=0.000000 rms=0.000000 dmesg_lines=0 wav=/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch.wav
```

## PCM runtime excerpts

```text

/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:format: S16_LE
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:hw_ptr      : 49919
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s16_48k_1ch-active.proc-asound:appl_ptr    : 49919
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:format: S24_LE
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:subformat: STD
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:channels: 1
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:rate: 48000 (48000/1)
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:state: RUNNING
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:hw_ptr      : 51839
/tmp/oneplus-mic-debug-gen64-coldboot-ucm-mic-20260614T125257Z/pmos_runtime_bottom_s24_48k_1ch-active.proc-asound:appl_ptr    : 51839
```

## Re-run command

```sh
nix run .#oneplus-mic-trial -- --mode 'pmos-runtime' --label 'gen64-coldboot-ucm-mic' --reset-note 'generation 64 cold boot with ACP-compatible Mic1 UCM visible in alsaucm; PipeWire initially exposes speaker sink but no mic source'
```
