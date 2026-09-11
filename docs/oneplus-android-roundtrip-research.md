# OnePlus 6T Android roundtrip: online research

Research date: **2026-09-11**. Companion to the
[operator runbook](oneplus-android-roundtrip.md).

Scope: international/non-T-Mobile A6013, as requested. No shell commands,
builds, restore-kit downloads, archive inspection, USB actions or flashing were
performed in this research pass. The local flake lock was read to identify the
exact Nixpkgs source to consult online. Commands below are instructions/examples,
not an execution log. Verify publication of this note and the runbook before
wiping the phone.

## Evidence levels and limits

- **Device documentation:** device-maintainer wiki or original implementation.
- **Source-established:** behaviour visible in the cited software source; not a
  claim of successful execution on this phone.
- **Community procedure/package:** attributable report or listing, not vendor
  certification or independently verified archive contents.
- **Still unverified:** availability of actual download mirrors, downloaded-file
  integrity, device-specific execution, or compatibility not established by sources.

Some XDA pages returned HTTP 403 and the postmarketOS wiki presented an Anubis
access challenge. Where noted, the search service used indexed page content.
Do not attribute secondary-guide instructions to an inaccessible XDA maintainer.

## 1. Physical modes: EDL versus factory fastboot

The [fajita device wiki][pmos-fajita] is a separate page which refers readers to
the [OnePlus 6 page][pmos-enchilada] for shared installation guidance.

### Enter EDL — device-documented

1. Disconnect USB and completely power off the phone.
2. Hold **Volume Up + Volume Down** together.
3. While holding them, connect USB to the computer.
4. After a few seconds, release the buttons.

The 6T page describes the phone as appearing to do nothing: a black screen is
not evidence of failed EDL entry. Confirm the USB device on the computer.
**Do not expect an indicator LED based on another phone's guide.**

Windows should show **Qualcomm HS-USB QDLoader 9008 (COM...)** when its driver is
bound. Microsoft's [driver catalogue entry][ms-driver] lists hardware ID
`USB\VID_05C6&PID_9008`. `QUSB_BULK`/an unknown USB device can indicate a missing
driver, rather than proving the phone did not enter EDL.

This is now a documented procedure, but it has not been tried from this phone's
current NixOS/U-Boot state during preparation.

### Exit EDL — device-documented, timings vary

The fajita page says hold **Power for 10–15 seconds** to restart. A secondary
[MSM guide][msm-guide] also gives **Power + Volume Up for 20–30 seconds** if the
phone remains in EDL after a successful flash. These are different source
instructions, not a universal timing guarantee. Never interrupt an active flash.

### Enter factory ABL fastboot — device-documented

With USB disconnected and the phone off, hold **Power + Volume Up + Volume
Down**. After power-on/vibration, keep the volume buttons held until fastboot
appears. The shared wiki describes the screen with **START** at the top.

From an authorized, running Android installation, the original
[MatthewCroughan README][matthew-readme] instead uses `adb -d reboot bootloader`.

**Factory ABL fastboot, U-Boot's fastboot menu, Android recovery fastbootd and
Qualcomm EDL are distinct modes.** The [U-Boot Qualcomm phone documentation][uboot-phones]
warns about UFS support limitations in U-Boot's fastboot backend. Do not replace
factory-ABL flashing steps with U-Boot-fastboot steps.

## 2. Is a particular OxygenOS version required?

**No source found establishes OxygenOS 11.1.2.2 as a hard requirement for this
custom NixOS/U-Boot installation.**

- [Matthew's original README][matthew-readme] asks for OxygenOS **9.x or newer**
  before setup. It is the ancestor of this project's bring-up implementation.
- The shared [postmarketOS wiki][pmos-enchilada] recommends updating both slots,
  particularly for GPS, but explicitly describes updating as not a general
  installation requirement. Its GPS notes identify **9.0.16 for the 6T**
  (9.0.8 is the OnePlus 6 value). This is not evidence that newer firmware
  necessarily breaks GPS, nor proof that this exact kernel needs a downgrade.
- The [LineageOS firmware guide][lineage-firmware] asks for the latest Android
  11 stock firmware for its own installation. That does not establish the same
  requirement for this NixOS kernel.
- OnePlus's [11.1.2.2 announcement][oneplus-release] dates to December 3, 2021,
  and describes stability fixes and the November 2021 Android security patch.

A sensible stock diagnostic baseline is a coherent, identifiable, unmodified
manufacturer release. Latest stock is useful, but **11.1.2.2 remains a baseline
choice rather than a proven dependency**. Installing older stock through MSM
can be a valid recovery starting point. An exact supported upgrade chain from
that recovered release to 11.1.2.2 has not been established in this pass; do not
apply an incremental OTA to the wrong starting build.

Firmware written during Android restoration can matter on the subsequent Linux
boot. Record the chosen stock build and distinguish that firmware baseline from
Nix-provided firmware files and the cached Linux kernel.

## 3. Windows MSM recovery: concrete candidates and procedure

### Package candidates — metadata checked, archives not verified

| Candidate | Attributable listing | Evidence and limitations |
| --- | --- | --- |
| `fajita_41_J.50_210121.zip` | [AndroidFileHost][afh-1038] | Listed as OnePlus 6T, 2.2 GB, uploaded by `Some_Random_Username` on 2021-02-11. The [secondary device-specific guide][msm-guide] identifies it as the international/decrypted OxygenOS 10.3.8 MSM package. AFH metadata alone does not prove region or contents. |
| `6T_MsmDownloadTool_v4.0.59_OOS_v9.0.13.rar` | [AndroidFileHost][afh-9013] | Listed as OnePlus 6T, 1.8 GB, uploader `iaTa`; appears in the older MSM distribution lineage. Not an authenticated vendor-hosted kit. |

Published AFH MD5 values (metadata only):

- 10.3.8: `677ace2358c3a963bc56597101b4b93f`.
- 9.0.13: `ed0465352b4f00bb3d8fdc40e1e82af3`.

The pages expose download buttons, but **an operational archive mirror was not
confirmed**. No payload was downloaded or hashed. MD5 can compare against the
publisher's listing, but is not strong proof of authenticity. Prefer provenance
and package inspection rather than treating a matching MD5 as certification.

The [original 6T MSM thread][xda-msm] was located, but direct access returned
403. The exact settings of its current first post were not independently read.
Avoid OnePlus 6/enchilada packages and patched T-Mobile conversion kits.

### Drivers — prefer an attributable distributor

Microsoft's [Update Catalog][ms-driver-search] lists **Qualcomm HS-USB QDLoader
9008**; the inspected [entry][ms-driver] reports version 2.1.1.0 and x86/x64
support. Prefer this distribution source over random repackaged EXE links.
Actual compatibility with the user's Windows installation is still to be checked.
Do not pre-emptively disable Windows signature enforcement or security tools.

### MSM procedure — secondary 6T-specific guide, not executed

The [guide][msm-guide] documents this order:

1. Extract the correct full recovery kit.
2. Launch its `MsmDownloadTool V4.0.exe` on Windows.
3. Enter EDL with the button/USB sequence above.
4. Confirm **Connected** and a COM port in MSM.
5. Click **Start**.
6. Wait for the successful green download/progress indication and automatic
   OxygenOS boot; do not disconnect during transfer.
7. Stop/close the tool and disconnect after completion.

Treat the process as a **complete wipe and bootloader relock**, as the guide and
older indexed recovery instructions warn. Check actual lock state afterward;
never add an independent manual relock step while custom partitions remain.

Some other community accounts recommend Start-before-connect to address timing
problems. That was not verified against the original 6T maintainer's first post,
and advice from other OnePlus models must not become this device's canonical
procedure. Likewise, do not improvise SMT/factory modes, firehose selections,
partition lists or calibration writes in response to a connection failure.

## 4. OxygenOS full OTA versus fastboot bundle versus MSM kit

These are different artifacts and are not interchangeable.

### Historical official-hosted 11.1.2.2 full OTA URL

The [FSFE OnePlus workshop page][fsfe] records this full 6T package:

`OnePlus6TOxygen_34.J.62_OTA_0620_all_2111252336_f6eda340d7af4e3e.zip`

[Historical OnePlus-hosted URL][ota-11122]; reported size about 2.05 GB and MD5
`fb113b6ccf7376a49399f40de9bb3cbe`. These are referenced metadata, **not a current
successful download or independent hash verification**. The workshop page did
not yield a complete, verified stock-restoration procedure through the search
interface in this pass; do not infer one from its download reference.

A full OTA is not an MSM kit and cannot simply be supplied as a raw image to
`fastboot flash userdata`. An incremental OTA is additionally tied to its exact
base build. A firmware-only extraction does not install Android system/vendor.

### Additional community 11.1.2.2 fastboot bundle found

[SourceForge `oneplus-6-series`][sf-11122] lists
`11.1.2.2-OP6T-FASTBOOT.zip`, 2.6 GB, modified 2022-01-28, under maintainer
`siddhrsh`. This is a separate community project from
[mauronofrio's `fastbootroms`][sf-mauronofrio].

The filename/listing presents it as a fastboot bundle, **not an official
OnePlus-hosted OTA**. Contents, scripts, signing, exact upstream attribution and
archive integrity remain uninspected. Do not claim that the package's author or
contents have been authenticated merely because the OS version is official.

## 5. Linux stock restoration: stronger lead, still not a ready script

A [2020 /e/ community report][e-restore] describes successfully restoring a 6T
using Manjaro Linux and a mauronofrio fastboot-ROM archive. It extracts
`images.zip` and flashes stock boot, DTBO, system, vendor, vbmeta and various
firmware partitions, largely to both slots. It does not identify the exact OOS
build, so it is **not validation of the later 11.1.2.2 bundle**.

Importantly, its command list also flashes a generic `persist.img`. **Do not
copy that operation into this phone's runbook.** Per-device calibration/identity
partitions need separate justification and user-owned recovery handling.
The post gives no manual relock step and is not proof that locked bootloaders
allow all its operations. Exact archive contents, slot/data-format handling,
critical-partition permissions and recovery behaviour still need review.

This is evidence that Linux full-stock restoration is feasible, not that Windows
MSM is the only possible route. It is not yet a vetted command list for this
phone's current state. No need to rewrite the outer GPT merely because a nested
GPT lives inside userdata.

### Temporary TWRP is not a verified shortcut to OxygenOS 11

[TeamWin's official fajita page][twrp] documents temporary `fastboot boot` and
notes that recovery lives in boot, not a separate recovery partition. It does
not establish a complete, working OOS11 restore recipe.

The relevant [fajita-specific TeamWin issue #5][twrp-issue] reports CrashDump
when temporarily booting `twrp-3.5.2_9-0-fajita.img` after OxygenOS 11.1.1.1.
It is **not** the unrelated issue #5 in `TeamWin/Team-Win-Recovery-Project`.
Do not pair an arbitrary old TWRP with OOS11 and call the result verified.

The [LineageOS firmware-only instructions][lineage-firmware] use recovery
fastbootd. They are neither a complete Android restoration nor interchangeable
with the factory-ABL commands used to install this U-Boot image.

## 6. Returning to NixOS: image format resolved from pinned source

The root `nixpkgs` input in this checkout resolves to
`21ea275a7c46aef9d4d6ddc962e6d562e9d94183` (not the separate kernel Nixpkgs pin).
Its [repart module][nix-repart], [builder][nix-repart-builder] and
[version options][nix-version] establish:

- Compression defaults to **Zstandard**.
- Image extension is **`.raw.zst`** when compression is enabled.
- `image.repart.version` defaults to `system.image.version`, which defaults to
  **null**. A non-null override adds `_<version>` to the basename.
- With this project's `image.repart.name = "image"` and the default version,
  the expected main output is **`$out/image.raw.zst`**.
- The builder removes the uncompressed `.raw` after successful compression.
- `sectorSize = 4096` controls disk sector geometry, not the compressed filename.

Thus an expected preparation command, after building/locating the output, is:

```sh
zstd --decompress --stdout result-oneplus-image/image.raw.zst \
  > oneplus-userdata.raw
```

Check the actual output before using this path; no full configuration evaluation
or artifact inspection was performed in this research pass. Available host disk
space and the expanded image's size versus userdata still need checking.

### Raw/sparse handling is not an unsolved file-format design

AOSP's [fastboot implementation][fastboot-source], [protocol][fastboot-protocol]
and [libsparse interface][libsparse] show that the host can import an ordinary
raw byte stream as Android sparse data and split it into smaller transfers.
The raw bytes need not contain an Android filesystem; a nested GPT is not a
special obstacle to the host-side importer.

Normally fastboot queries `max-download-size` and uses that to decide whether
splitting is necessary. `-S SIZE` can explicitly select a sparse-transfer limit.
Do not pick a supposedly universal size: check the target's reported limit and
the actual host fastboot version. An explicit value must not exceed what the
device accepts merely because a desktop has enough RAM.

The source-supported candidate operation is therefore:

```sh
fastboot flash userdata oneplus-userdata.raw
```

**This is not yet a tested phone-installation command.** Device-side sparse
acceptance, transfer limits, partition size, successful writes and fresh boot
must still be verified. Separate `img2simg` preprocessing is not automatically
required. Do not flash the Zstandard-compressed file as if it were raw.

Fastboot targets the existing outer `userdata` partition. It does not interpret
the nested GPT as a request to repartition the whole phone. U-Boot/Linux later
interpret the nested layout. Do not format userdata after installing this image.

### Keep this project's U-Boot recipe

Generic [U-Boot Qualcomm examples][uboot-board] use example addresses and evolving
config names. They are not replacements for this project's pinned fajita recipe
(`--base 0x0`, `--kernel_offset 0x8000`, gzip then appended DTB, 4096-byte Android
boot-image pages, custom A/B helper/environment). Use the tracked Nix derivation,
not a new recipe assembled from current generic examples.

## 7. What still needs more than online research?

| Task | Online/source research achieved | Remaining action |
| --- | --- | --- |
| EDL / factory-fastboot entry | Device-specific combinations and indicators documented | User operates buttons/USB; confirm enumeration |
| Windows driver | Microsoft-distributed candidate identified | Install/bind it on the chosen Windows machine |
| MSM package | Concrete 10.3.8 and older candidates with metadata | Confirm working mirror, obtain/inspect/hash archive, accept provenance |
| Firmware version | No demonstrated NixOS requirement for 11.1.2.2; separate GPS/Lineage guidance identified | Choose coherent baseline; confirm any upgrade chain and later hardware behaviour |
| Linux stock alternative | Successful historical Linux report plus newer archive listing | Audit a particular archive and safe flash sequence; do not copy persist writes |
| Nix image format | Pinned source establishes raw + Zstandard, expected filename | Build/use existing correct output, inspect geometry, contents and size |
| Fastboot image transfer | Raw-to-sparse conversion and limits explained from AOSP | Query actual factory bootloader and test transfer during authorized reinstall |
| U-Boot | Existing pinned recipe and upstream installation provenance | Fresh build/artifact check; later flash/boot confirmation |
| First-boot access/root growth | Cannot be established by another distro's guide | Audit current configuration, inspect image, then verify actual first boot |
| Private identity and diagnostics | Can document required user steps | User-managed secrets and physical stock hardware tests |

No shell-based validation or build checks were run, in accordance with the
research-only request. This note is evidence to finish the runbook, not approval
to flash any listed package.

[pmos-fajita]: https://wiki.postmarketos.org/wiki/OnePlus_6T_(oneplus-fajita)
[pmos-enchilada]: https://wiki.postmarketos.org/wiki/OnePlus_6_(oneplus-enchilada)
[ms-driver]: https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=bcdb99c1-fd4a-4ded-a97f-5bcf6e57fb58
[ms-driver-search]: https://www.catalog.update.microsoft.com/Search.aspx?q=Qualcomm+HS-USB+QDLoader+9008
[matthew-readme]: https://github.com/MatthewCroughan/nixos-sdm845/blob/0f53170550bb817f2c15024d7adb2cf2b842be8d/README.md
[uboot-phones]: https://docs.u-boot.org/en/v2026.04/board/qualcomm/phones.html
[uboot-board]: https://docs.u-boot.org/en/latest/board/qualcomm/board.html
[lineage-firmware]: https://lineageos.github.io/lineage_wiki/devices/fajita/fw_update/variant1/
[oneplus-release]: https://community.oneplus.com/thread/1523813
[afh-1038]: https://androidfilehost.com/?fid=17248734326145733776
[afh-9013]: https://androidfilehost.com/?fid=1395089523397966003
[msm-guide]: https://www.thecustomdroid.com/oneplus-6-6t-unbrick-guide/
[xda-msm]: https://xdaforums.com/t/tool-6t-msmdownloadtool-v4-0-oos-9-0-5-t3867448/
[fsfe]: https://wiki.fsfe.org/Activities/Android/UpcyclingWorkshops/FlashingOnePlusPhones
[ota-11122]: https://oxygenos.oneplus.net/OnePlus6TOxygen_34.J.62_OTA_0620_all_2111252336_f6eda340d7af4e3e.zip
[sf-11122]: https://sourceforge.net/projects/oneplus-6-series/files/Fastboot%20Rom/11.1.2.2-OP6T-FASTBOOT.zip/
[sf-mauronofrio]: https://sourceforge.net/projects/fastbootroms/files/OnePlus%206T/
[e-restore]: https://community.e.foundation/t/howto-oneplus-6t-roll-back-to-stock-oxygenos-rom-after-a-brick-being-stuck-in-a-loop/16680
[twrp]: https://twrp.me/oneplus/oneplus6t.html
[twrp-issue]: https://github.com/TeamWin/android_device_oneplus_fajita/issues/5
[nix-repart]: https://raw.githubusercontent.com/NixOS/nixpkgs/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/image/repart.nix
[nix-repart-builder]: https://raw.githubusercontent.com/NixOS/nixpkgs/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/image/repart-image.nix
[nix-version]: https://raw.githubusercontent.com/NixOS/nixpkgs/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/misc/version.nix
[fastboot-source]: https://android.googlesource.com/platform/system/core/+/refs/heads/main/fastboot/fastboot.cpp
[fastboot-protocol]: https://android.googlesource.com/platform/system/core/+/refs/heads/main/fastboot/README.md
[libsparse]: https://android.googlesource.com/platform/system/core/+/master/libsparse/include/sparse/sparse.h
