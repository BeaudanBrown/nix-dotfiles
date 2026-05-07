{ pkgs, ... }:
let
  uboot = pkgs.callPackage ./sdm845-uboot.nix { };
in
pkgs.runCommand "sdm845-oneplus-fajita-uboot-bootimg"
  {
    nativeBuildInputs = with pkgs; [
      android-tools
    ];
  }
  ''
    cp ${uboot}/u-boot-nodtb.bin ./u-boot-nodtb.bin
    cp ${uboot}/sdm845-oneplus-fajita.dtb ./sdm845-oneplus-fajita.dtb
    gzip ./u-boot-nodtb.bin
    cat ./u-boot-nodtb.bin.gz ${uboot}/sdm845-oneplus-fajita.dtb > ubootwithdtb
    mkbootimg \
      --kernel ./ubootwithdtb \
      --base "0x0" \
      --ramdisk /dev/null \
      --kernel_offset "0x8000" \
      --pagesize 4096 \
      -o $out
  ''
