# https://docs.u-boot.org/en/latest/board/qualcomm/board.html
{
  buildUBoot,
  xxd,
  bison,
  flex,
  openssl,
  gnutls,
  android-tools,
}:
buildUBoot {
  version = "master";
  src = builtins.fetchGit {
    url = "https://git.codelinaro.org/clo/qcomlt/u-boot.git";
    rev = "6fc40f2499b1a517487933d7d81a482f6dce7751";
  };
  extraConfig = ''
    CONFIG_CMD_HASH=y
    CONFIG_CMD_BLKMAP=y
    CONFIG_BLKMAP=y
    CONFIG_CMD_UFETCH=y
    CONFIG_CMD_SELECT_FONT=y
    CONFIG_VIDEO_FONT_16X32=y
    # Do not show U-Boot's bootmenu before running bootcmd. The recovery menu
    # remains available via `run menucmd` after a failed boot or from the shell.
    # CONFIG_AUTOBOOT_MENU_SHOW is not set

    # Avoid spurious serial/button-kbd input aborting autoboot. With keyed
    # autoboot, only the configured bootstopkey (or Ctrl-C) interrupts boot.
    CONFIG_AUTOBOOT_KEYED=y
    CONFIG_AUTOBOOT_FLUSH_STDIN=y
    CONFIG_AUTOBOOT_KEYED_CTRLC=y
    CONFIG_BOOTDELAY=5
  '';
  prePatch = ''
    cp ${../assets/qcom-phone.env} board/qualcomm/qcom-phone.env
  '';
  extraMakeFlags = [ "DEVICE_TREE=qcom/sdm845-oneplus-fajita" ];
  defconfig = "qcom_defconfig phone.config";
  extraMeta.platforms = [ "aarch64-linux" ];
  nativeBuildInputs = [
    xxd
    bison
    flex
    openssl
    gnutls
    android-tools
  ];
  filesToInstall = [
    "u-boot*"
    "dts/upstream/src/arm64/qcom/sdm845-oneplus-fajita.dtb"
  ];
}
