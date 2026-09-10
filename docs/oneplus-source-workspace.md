# OnePlus / SDM845 Source Workspace

A local read-only source workspace has been prepared at:

```sh
/home/beau/src/oneplus-debug
```

It is intentionally outside this dotfiles repository so large cloned source trees do not affect `git status`.

## Cloned repositories

Current shallow clones:

| Directory | Purpose |
| --- | --- |
| `linux-sdm845-mainline` | Mainline SDM845 kernel/reference DTS and drivers |
| `firmware-oneplus-sdm845` | SDM845 OnePlus firmware layout/package reference |
| `tqftpserv` | Upstream Linux QRTR TFTP server source |
| `rmtfs` | Upstream Linux remote filesystem daemon source |
| `qrtr` | QRTR tooling/library reference |
| `libqmi` | QMI protocol/client definitions and `qmicli` source |
| `ModemManager` | Qcom SoC plugin, DPM/WDA/WDS, modem port expectations |
| `android_device_oneplus_fajita` | Lineage device tree for OnePlus 6T |
| `android_device_oneplus_sdm845-common` | Shared Lineage OnePlus SDM845 device tree |
| `android_kernel_oneplus_sdm845` | Downstream/Lineage OnePlus SDM845 kernel reference |
| `hardware_qcom_gps` | AOSP/Qualcomm GPS HAL source |
| `pmaports` | postmarketOS device packages and downstream mobile Linux references |

## Common search entry points

```sh
cd /home/beau/src/oneplus-debug

# Current GNSS/modem blocker: DMS offline, no bands, LOC engine off.
rg -n "DMS|DeviceNotReady|operating mode|offline|bands|rmnet|IPA|DPM|WDA|QMI_LOC|engine-state|GPS_LOCK" .

# IPA/rmnet/data-port bring-up and device tree expectations.
rg -n "qcom,sdm845-ipa|ipa@1e40000|rmnet|wwan|bam-dmux|qcom-q6v5-mss|DATA.*_CNTL" \
  linux-sdm845-mainline android_kernel_oneplus_sdm845 ModemManager libqmi pmaports 2>/dev/null

# Qualcomm remote filesystem/TFTP path compatibility.
rg -n "tftp|rmtfs|/vendor/rfs|/readwrite|/readonly|modem_fsg|oem_nvbk|modem_pr|mcfg" .

# Android/vendor location stack and QMI LOC behavior.
rg -n "loc_launcher|xtra-daemon|mlid|ssgqmigd|ipacm|gnss_service|android.hardware.gnss|QMI_LOC_START|GPS_LOCK" \
  android_device_oneplus_* android_kernel_oneplus_sdm845 hardware_qcom_gps libqmi 2>/dev/null
```

## Updating clones

These are shallow clones. To refresh one tree:

```sh
cd /home/beau/src/oneplus-debug/<repo>
git pull --ff-only
```

To record what source revisions were consulted:

```sh
cd /home/beau/src/oneplus-debug
for d in */.git; do r=${d%/.git}; printf '%-40s ' "$r"; git -C "$r" rev-parse --short HEAD; done | sort
```

## Safety reminders for live OnePlus debugging

- Do not probe `/dev/wwan0at*`; direct AT probing has wedged the rpmsg/WWAN path.
- Do not live `modprobe ipa`; explicit IPA probing has crashdumped this phone.
- Do not live-restart `rmtfs`; boot into rmtfs changes instead.
- Treat PDC activation as persistent state. If a config becomes `Pending`, deactivate it before stopping.
- Use `switch` for helper/userspace changes; reboot is needed for modem remoteproc, rmtfs, and boot-time TFTP/RFS behavior.

## Stock firmware experiment

A local copy of the phone's own `modem_a` firmware has been prepared at:

```sh
/home/beau/src/oneplus-debug/oneplus-stock-firmware
```

It was copied from the mounted OxygenOS `modem_a` partition and then `pil-squasher` was built in:

```sh
/home/beau/src/oneplus-debug/pil-squasher
```

`pil-squasher` was used to create single-file `modem.mbn`, `adsp.mbn`, `cdsp.mbn`, and `slpi.mbn` from the stock `.mdt` + `.bXX` files. The local store path currently is:

```sh
/nix/store/slb6brqn44cgcv8by5vdc4yw9divkmfn-oneplus-stock-firmware
```

`hosts/oneplus/oneplus-fajita/hardware/sdm845.nix` has an environment-gated debug overlay. Normal pure flake evaluation keeps using the prepackaged `sdm845-mainline/firmware-oneplus-sdm845` bundle. To test the stock firmware overlay, build/switch with an impure environment variable:

```sh
export ONEPLUS_STOCK_FIRMWARE_STORE=/nix/store/slb6brqn44cgcv8by5vdc4yw9divkmfn-oneplus-stock-firmware
nix eval --impure .#nixosConfigurations.oneplus.config.system.build.toplevel.drvPath --raw
# If explicitly doing a rebuild/switch for this experiment, preserve the env var and pass --impure.
```

Why this matters: the currently running prepackaged modem image reports `MPSS.AT.4.0.c2.15-00007-SDM845_GEN_PACK-1.358880.1.399256.2`, while this phone's `modem_a/verinfo` reports `...1.276740.1.331501.2`. With DMS stuck offline, `DMS --get-capabilities` showing zero rates and empty networks, bands `none`, UIM `no-atr`, and LOC engine `off(2)`, a firmware/NV mismatch is now a strong candidate to test before risky IPA work.

## Current GNSS/modem conclusion to preserve

As of the patched `tqftpserv` boot validation, the simple firmware/RFS path theory is lower probability: the patched TFTP service was active from boot and no GPS/DMS state improved. The next likely research area is testing phone-local modem firmware alignment, then IPA/rmnet/data-port/modem readiness versus deeper modem RF/NV state. Use these local trees for read-only comparison before any risky live driver or remoteproc experiments.
