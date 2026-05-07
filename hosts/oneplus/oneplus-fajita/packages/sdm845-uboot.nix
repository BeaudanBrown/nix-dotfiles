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
