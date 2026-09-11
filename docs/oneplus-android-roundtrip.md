# OnePlus 6T: source-based Android / U-Boot / NixOS round trip

Goal: pause hardware bring-up, use stock Android, then reconstruct U-Boot/NixOS
from published source and continue development. **Binary partition backups are
optional recovery insurance, not the requested deliverable.** The user handles
personal data, secrets and any backups; agents must not inspect private keys,
NV/calibration contents or the private secrets repository.

Proceed as **international/non-T-Mobile A6013**, by explicit user instruction.
This is an assumption, not verified original sales provenance. Prefer Linux for
flashing; native Windows/MSM is available as a fallback. No flashing, reboot or
Nix build was performed while preparing this document. Instructions below are
for later explicit execution, not proof of a completed reinstall test.

## Published source and remaining reconstruction gaps

| Work | Canonical source / revision | Status |
| --- | --- | --- |
| Fleet and current OnePlus configuration | [BeaudanBrown/nix-dotfiles](https://github.com/BeaudanBrown/nix-dotfiles/tree/oneplus-mobile-rebased), `oneplus-mobile-rebased` | Source-preservation branch, including this preparation; cleanup baseline is `origin/master`, not local `master` |
| Mobile Hyprspace changes | [BeaudanBrown/Hyprspace](https://github.com/BeaudanBrown/Hyprspace/tree/oneplus-preview-drag), `d1d98d40295b59d6a4655cd43d96ec631b109eed` | Fork created and branch publication verified; dotfiles now pins this GitHub source, not a local path |
| Earlier bring-up project | [BeaudanBrown/nixos-sdm845](https://github.com/BeaudanBrown/nixos-sdm845/tree/native), `291a99adca6148cddcd54704a4fe2d3cb9b2d55a` | Existing local configuration changes and Justfile committed/pushed; editor swap excluded |
| Kernel source | [sdm845/linux](https://codeberg.org/sdm845/linux), `77ae339cc73c48bc37efbcb7b64d4e7cd0b158ae` | Local nested checkout was clean; no local kernel patch commits to publish from it |
| U-Boot source | `https://git.codelinaro.org/clo/qcomlt/u-boot.git`, `6fc40f2499b1a517487933d7d81a482f6dce7751` | Custom changes are tracked in dotfiles, not an unpublished U-Boot checkout; remote HEAD was reachable |

Clean upstream research clones are references, not unpublished implementation.
See [source workspace](oneplus-source-workspace.md) for their purpose. The
legacy `nixos-sdm845` flake still names a phone-local kernel checkout: it is
published historical work, **not** the canonical fresh-install entrypoint.
Use this dotfiles flake for the process below.

### Kernel: the important remaining gap

The active [SDM845 module](../hosts/oneplus/oneplus-fajita/hardware/sdm845.nix)
uses `fetchClosure` to wrap cached kernel/module binaries. Updating the kernel
source input does not change that kernel. The older
[kernel recipe](../hosts/oneplus/oneplus-fajita/hardware/kernel.nix) exists but
is not wired into the active package and is not established as reproducing it.

The running kernel's complete Kconfig has now been preserved as source:

- [kernel-7.0.0.config](../hosts/oneplus/oneplus-fajita/assets/kernel-7.0.0.config)
- Obtained by decompressing `/proc/config.gz` on the running phone.
- Kernel release: `7.0.0-next-20260414-sdm845`.
- SHA-256: `06d0f0ebb28eb850477ee9e29b2a094656588f58249b0f9943c1598a80f18dc2`.

Before calling source-only reconstruction complete, add/validate a selectable
source-build recipe using the correct source, config, patches and toolchain,
without silently replacing the stable runtime kernel. This requires explicit
approval before any kernel build. Until then, the normal NixOS build still
depends on the configured Attic cache; preserving source has not removed that
dependency. The source revision plus Kconfig is not a claim of bit-identical
reproduction of the old cached build.

## U-Boot is already maintained in this repository

| Component | File |
| --- | --- |
| Pinned upstream source, fajita build flags | [sdm845-uboot.nix](../hosts/oneplus/oneplus-fajita/packages/sdm845-uboot.nix) |
| Android boot-image packaging | [uboot-bootimg.nix](../hosts/oneplus/oneplus-fajita/packages/uboot-bootimg.nix) |
| Boot menu, userdata mapping, EFI boot command | [qcom-phone.env](../hosts/oneplus/oneplus-fajita/assets/qcom-phone.env) |
| Qualcomm A/B boot-success command | [patch](../hosts/oneplus/oneplus-fajita/patches/0001-cmd-add-qcom-ab-success-command.patch) |
| Public build output | [flake.nix](../flake.nix), `oneplus-uboot-bootimg` |

The recipe builds `qcom_defconfig phone.config` with the fajita device tree,
gzips `u-boot-nodtb.bin`, appends `sdm845-oneplus-fajita.dtb`, and wraps it with
`mkbootimg`: base `0x0`, kernel offset `0x8000`, page size 4096, empty ramdisk.
Preserving these source files is the intended way to regenerate U-Boot.

### Generate the boot image on a Linux build host

After source publication, from a clone of the prepared branch:

```sh
git clone --branch oneplus-mobile-rebased https://github.com/BeaudanBrown/nix-dotfiles.git
cd nix-dotfiles
# Explicit build: only run when ready/approved to build.
nix build .#oneplus-uboot-bootimg --out-link result-oneplus-uboot
UBOOT_IMAGE="$(readlink -f result-oneplus-uboot)"
test -f "$UBOOT_IMAGE"
sha256sum "$UBOOT_IMAGE"
```

The flake chooses the build host's package set and cross-compiles U-Boot to
AArch64. This U-Boot output does not require an installed NixOS phone. Source
fetch/build on a fresh external host remains to be tested; a reachable upstream
HEAD alone does not prove the pinned commit can still be fetched and built.

### Flash U-Boot from stock Android

**Destructive, later user-operated steps.** First preserve anything the user
wants to keep. Confirm the device is the intended fajita, the bootloader is
unlocked, the generated image is valid, and a compatible NixOS userdata image
and stock recovery route are ready. Unlocking itself wipes Android data; do
not issue unlock commands to an already-unlocked phone or relock custom images.

Use the **factory ABL bootloader**, not U-Boot's own fastboot mode or recovery
fastbootd. TeamWin and LineageOS document factory-fastboot access for fajita;
confirm the screen/USB mode rather than relying on an ambiguous reboot wrapper.
On the external Linux computer, with `android-tools` available:

```sh
fastboot devices
# With multiple connected devices, add -s <chosen-device> to every command.
fastboot getvar product
fastboot getvar current-slot
```

After completing those gates, the original project's recorded mainline U-Boot
installation sequence is:

```sh
# Erases Android's DT overlays, then replaces both Android boot images.
fastboot erase dtbo_a
fastboot erase dtbo_b
fastboot --slot=all flash boot "$UBOOT_IMAGE"
```

This sequence is preserved from the local bring-up README and agrees with
U-Boot's generic Android boot-image/DTBO approach. It has **not** been replayed
in this preparation pass. Do not treat a TWRP image or raw partition backup as
interchangeable with the generated U-Boot boot image. Do not reboot into the
normal NixOS boot path until userdata contains its compatible nested image.

Normal U-Boot `boot_nixos` calls `qcom_ab_success mark`: it sets boot-successful
and clears unbootable bits for both boot partitions in GPT. This is intentional
custom behavior and does write metadata. It then maps userdata and starts
`/EFI/BOOT/BOOTAA64.EFI` from nested partition 2. Holding Volume down during
U-Boot startup opens the configured recovery menu; see the environment source.

## Recreate NixOS inside userdata

The [repart module](../hosts/oneplus/oneplus-fajita/image/repart.nix) defines a
4096-byte-sector nested GPT: padding, FAT ESP, ext4 root. The
[initrd](../hosts/oneplus/oneplus-fajita/hardware/sdm845.nix) maps the Android
partition named `userdata` using `losetup --partscan --sector-size 4096`.

```sh
# Explicit build: needs the pinned inputs and an AArch64-capable builder.
nix build .#nixosConfigurations.oneplus.config.system.build.image \
  --out-link result-oneplus-image
```

The output is configured to be compressed. **Remaining installation work:**
verify its produced filename/format, decompression, image size versus userdata,
and factory-fastboot raw/sparse transfer support. Then document and test the
exact userdata write command. Do not guess it or flash the image onto an entire
UFS disk: it belongs inside Android `userdata`, preserving the outer layout.
This is a missing piece of the fresh-install procedure, not a reason to require
an old userdata backup instead.

The configured boot flow is ABL → U-Boot → nested ESP → systemd-boot → Linux.
The inspected system selected generation 133 with separate kernel/initrd/DTB
files under `/boot/EFI/nixos`; the older `/EFI/Linux/nixos.efi` alone was not the
active entry. After reinstalling, verify the booted generation, root/ESP mounts,
networking and SSH. User-managed secrets/identity must be restored or re-enrolled
separately; do not expect firmware or Git to recreate credentials.

[Existing fsck recovery notes](../hosts/oneplus/oneplus-fajita/README.md#u-boot-fsck-recovery)
are repair instructions, not the fresh installation procedure.

## Return to stock Android

Target: full international OxygenOS; 11.1.2.2 / Android 11 is the candidate,
not yet a verified download/restore kit. Backups and private data handling are
user-owned. The old TWRP backup contains valuable boot/firmware and EFS/persist
insurance, but the supplied listing has no system/vendor images. Its recovery
log identifies TWRP and slot B, not the backed-up OxygenOS version. Identifying
that old ROM is **not** a prerequisite for installing complete compatible stock.

- **Linux candidate:** factory fastboot → temporary compatible recovery → full
  OxygenOS installation with explicit slot/data-format handling. Avoid permanent
  TWRP/Magisk installation before the untouched-stock reference capture.
- **Windows fallback:** matching international MSMDownloadTool/EDL package.
  Native Windows avoids VM USB passthrough failure modes. Package provenance,
  compatibility and destructive scope still need verification.
- Do not substitute LineageOS's firmware-only flash list for an Android install.
  Its fastbootd instructions are not factory-fastboot instructions.
- Restoring Android requires compatible stock boot/DTBO and the complete Android
  partition set; formatting userdata alone while leaving U-Boot cannot do it.
- Do not generically erase/restore EFS, persist or other device-specific state,
  and do not relock with a partially restored/custom boot stack.

Research sources and limitations:

- [TeamWin fajita instructions](https://twrp.me/oneplus/oneplus6t.html) confirm
  temporary recovery boot and recovery residing in `boot`, not a separate
  recovery partition. [Download listing](https://dl.twrp.me/fajita/).
- [TeamWin issue #5](https://github.com/TeamWin/android_device_oneplus_fajita/issues/5)
  reports older TWRP crashdumping on OxygenOS 11; select recovery by demonstrated
  compatibility, not filename/version alone.
- [Maintainer's fastboot-ROM archive](https://sourceforge.net/projects/fastbootroms/files/OnePlus%206T/)
  lists 10.3.6 as the newest 6T entry observed. Do not downgrade casually or use
  its global latest-download button, which advertised a different phone.
- [LineageOS firmware guide source](https://github.com/LineageOS/lineage_wiki/blob/main/_includes/templates/device_specific/firmware_update_oneplus_fastbootd.md)
  recommends full updates via Oxygen Updater. The updater API returned HTTP 403
  during research; no full 11.1.2.2 package URL/checksum has been verified.
- [U-Boot Qualcomm documentation](https://github.com/u-boot/u-boot/blob/master/doc/board/qualcomm/board.rst)
  documents Android wrapping and DTBO conflicts. Its generic packaging examples
  do not override this repository's pinned recipe.

## Capture a useful stock hardware reference afterward

Before accounts/apps, root or custom kernels, record exact ROM/build, firmware,
kernel, slot, unlock/root state and successful hardware tests. Use a private
`adb bugreport` plus bounded, labelled before/during/after service snapshots.
[Android bugreport documentation](https://developer.android.com/studio/debug/bug-report)
explains its dumpsys/dumpstate/logcat contents. Raw reports can contain personal
identifiers and location: keep them private and publish sanitized conclusions.

Prioritize:

- Internal mic: known spoken phrase, repeat open/record/close in one boot, then
  cold-boot comparison. Record app/route and audible speech, not merely nonzero
  samples. Inspect `dumpsys audio`, `media.audio_flinger`, `media.audio_policy`.
- Bluetooth pairing/playback/capture and controller initialization.
- Outdoor GNSS fix, modem/SIM/IMS state where a usable network exists. The user
  already knows the Australian carrier limitation; do not mistake that for a
  hardware regression or make emergency test calls.
- Cameras, sensors, display/touch, charging and suspend/wake.

Only consider privileged capture afterward, with separate approval and a
record of baseline changes: kernel logs, mixer transitions, live device tree,
pinctrl/regulators and vendor configuration may help. Record access denials
rather than silently escalating; do not inspect keys or bulk NV state. Keep
stock-package provenance so static firmware/DTBO/vendor comparisons can be
repeated without reflashing. Future agents need an indexed comparison to
[specific Linux blockers](oneplus-bringup.md), not unstructured log dumps.

## First upstream experiment after returning

[`9f70dcdcc39be1e1df26691bd0ed73763bcd85c8`](https://codeberg.org/sdm845/linux/commit/9f70dcdcc39be1e1df26691bd0ed73763bcd85c8),
**slimbus: qcom-ngd-ctrl: Remove data channels on stream disable**, describes
WCD9340 capture recording zeros after prior stream channels are not removed.
Its `disable_stream` implementation was absent at our pinned source revision
and present at development tip `24104f135725e907d4f2b11851a1e68dc0d3c31d`.
This is a strong candidate for the [mic failure](oneplus-audio-readings.md), not
proof of a 6T fix or mainline merge. A kernel build/test requires new approval;
the old non-kernel-only investigation restriction is not silently lifted.

## Completion checklist

- [ ] Verify this dotfiles preparation commit is on the remote branch before
  erasing the phone; retain source history before squashing.
- [x] Publish Hyprspace fork and pin its source remotely.
- [x] Publish local changes in the older bring-up repository.
- [x] Preserve the running kernel configuration as source.
- [ ] Establish a source-build kernel path independent of cached binaries.
- [ ] Validate U-Boot generation from a fresh external checkout.
- [ ] Validate the fresh NixOS image and exact userdata installation procedure.
- [ ] Select a verified stock restore package/method and capture stock evidence.

This checklist distinguishes source publication from tested reconstruction.
There is no requirement to archive a whole running disk to satisfy the intended
source-based workflow.
