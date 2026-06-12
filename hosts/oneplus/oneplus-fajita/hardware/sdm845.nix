{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  kernelPkgs = import inputs.nixpkgs-oneplus-kernel {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  pinnedKernelOut = builtins.fetchClosure {
    fromStore = "https://attic.bepis.lol/fleet";
    fromPath = /nix/store/ngrdfwid2bqici5lnxl8gg5aqlmaard8-linux-7.0.0;
    inputAddressed = true;
  };
  pinnedKernelModules = builtins.fetchClosure {
    fromStore = "https://attic.bepis.lol/fleet";
    fromPath = /nix/store/5ii18dvifg1vpgwbmpb0bgqhp72yp8m5-linux-7.0.0-modules;
    inputAddressed = true;
  };
  oneplusKernel =
    kernelPkgs.runCommand "linux-7.0.0"
      {
        outputs = [
          "out"
          "dev"
          "modules"
        ];
        version = "7.0.0";
        modDirVersion = "7.0.0-next-20260414-sdm845";
        passthru = {
          # NixOS/nixpkgs expect these kernel package attributes, but this is
          # only a thin wrapper around the known-good kernel closure fetched
          # from Attic, not a full buildLinux result.
          commonMakeFlags = [ ];
          configfile = kernelPkgs.writeText "oneplus-kernel-config" ''
            CONFIG_ARCH_MMAP_RND_BITS_MAX=33
            CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MAX=16
          '';
          config = {
            isDisabled = _: true;
            isEnabled = _: true;
            isModule = _: true;
            isNo = _: true;
            isSet = _: true;
            isYes = _: true;
          };
          features = {
            efiBootStub = true;
            netfilterRPFilter = true;
          };
          isLTS = false;
          isZen = false;
          kernelAtLeast = version: lib.versionAtLeast "7.0.0" version;
          kernelOlder = version: lib.versionOlder "7.0.0" version;
          override = _: oneplusKernel;
          stdenv = kernelPkgs.stdenv;
        };
        meta.platforms = [ "aarch64-linux" ];
      }
      ''
        mkdir -p "$out" "$dev" "$modules"
        cp -a ${pinnedKernelOut}/. "$out"/
        cp -a ${pinnedKernelModules}/. "$modules"/
      '';
  firmware2 =
    let
      baseFw = pkgs.fetchFromGitLab {
        owner = "sdm845-mainline";
        repo = "firmware-oneplus-sdm845";
        rev = "3ec855b2247291c79652b319dfe93f7747363c86";
        sha256 = "sha256-7CaXWOpao+vuFA7xknzbLml2hxTlmuzFCEM99aLD2uk=";
      };
    in
    pkgs.runCommand "oneplus-sdm845-firmware"
      {
        inherit baseFw;
      }
      ''
        mkdir -p $out/lib/firmware
        cp -r $baseFw/lib/firmware/* $out/lib/firmware/
        chmod +w -R $out
        rm -rf $out/lib/firmware/postmarketos
        cp -r $baseFw/lib/firmware/postmarketos/* $out/lib/firmware
        ls -lah $out/lib/firmware/qcom/sdm845

        ${pkgs.tree}/bin/tree $out/lib/firmware/qcom/sdm845

        mkdir -p $out/lib/firmware/qcom/sdm845/OnePlus
        cd $out/lib/firmware/qcom/sdm845/OnePlus
        ln -s ../oneplus6 $out/lib/firmware/qcom/sdm845/OnePlus/enchilada

        mkdir -p $out/lib/firmware/qca/OnePlus
        cd $out/lib/firmware/qca/OnePlus
        ln -s ../oneplus6 $out/lib/firmware/qca/OnePlus/enchilada
      '';
in
{

  imports = [
  ];

  ## The bad way with kpartx
  #environment.variables.SYSTEMD_RELAX_ESP_CHECKS = "1";
  #boot.initrd.systemd.initrdBin = [ pkgs.multipath-tools ];
  #boot.initrd.services.udev.rules = ''
  #  SUBSYSTEM=="block", ACTION!="remove", ENV{ID_PART_ENTRY_NAME}=="userdata", RUN+="${pkgs.multipath-tools}/bin/kpartx -afs /dev/%k"
  #'';

  #environment.variables.SYSTEMD_RELAX_ESP_CHECKS = "1";

  boot.initrd.systemd.initrdBin = [ pkgs.util-linux ];
  boot.initrd.services.udev.rules = ''
    SUBSYSTEM=="block", ACTION!="remove", ENV{ID_PART_ENTRY_NAME}=="userdata", RUN+="${pkgs.util-linux}/bin/losetup --partscan --find --sector-size 4096 --loop-ref userdata /dev/%k"
  '';

  boot.initrd.includeDefaultModules = false;
  #      boot.initrd.availableKernelModules = lib.mkForce [];
  boot.initrd.systemd.tpm2.enable = false; # This also pulls in some modules our kernel is not build with.
  hardware.enableRedistributableFirmware = true;

  #system.nixos-init.enable = true;
  #system.etc.overlay.enable = true;
  #services.userborn.enable = true;
  #boot.initrd.systemd.enable = lib.mkForce false;
  #boot.initrd.extraFirmwarePaths = [
  #  "qcom/sdm845/oneplus6/ipa_fws.mbn"
  #  "qcom/sdm845/oneplus6/a630_zap.mbn"
  #  "qcom/sdm845/oneplus6/venus.mbn"
  #  "qcom/a630_sqe.fw"
  #  "qcom/a630_gmu.bin"
  #  "regulatory.db.p7s.zst"
  #  "regulatory.db.zst"
  #  "regulatory.db.p7s"
  #  "regulatory.db"
  #];

  boot.initrd.kernelModules = [
    "qcom_pd_mapper"
    #        "qcom-pm8008-regulator"
    #        "i2c_qcom_geni"
    #        "rmi_core"
    #        "rmi_i2c"
    #        "qcom_spmi_haptics"
    #        "arm-smmu"
    #
    #        "qcom-rng"
    #"icc-bwmon"
    #"msm"
    #        "ufshcd-core"
    ##        "ipa"
    #"qcom_rpmh"
    #"rpmhpd"
    #        "qcom_q6v5_mss"
    #        "qcom_q6v5_pas"
    #        "i2c-qcom-cci"
    #        "i2c-qcom-geni"
    #        "qcom-camss"
    #        "venus-core"
    #
    #        "gpucc_sdm845"
    #        "gcc_sdm845"
    #        "camcc-sdm845"
    #        "videocc-sdm845"
    #        "lpasscc-sdm845"
    #        "dispcc_sdm845"
    #        "clk_qcom"
    ##
    #    "pmic_glink"
    #    "ucsi_glink"
    #    "msm"
    #    "qcom-camss"
    #    "arm-cci"
    #    "qnoc-sdm845"
    #      ];
    #  boot.kernelModules = [
    #    # Testing
    #"ufs-qcom"
    #
    #    "phy-qcom-qmp-combo"
    #    "phy-qcom-qmp-ufs"
    #    "phy_qcom_qmp_usb"
    #    "qcom_spmi_haptics"
    #
    #    "i2c_qcom_geni"
    #    "rmi_core"
    #    "rmi_i2c"
    #
    #
    #"qcom_pil_info"
    #"qcom_q6v5"
    #"qcom_sysmon"
    #"qcom_common"
    #"qcom_glink_smem"
    #"mac80211"
    #"snd_soc_qcom_common"
    #"v4l2_mem2mem"
    #"videobuf2_v4l2"
    #"venus_core"
    #"rmi_core"
    #"bq27xxx_battery"
    #
    #
    "sd_mod"
    "scsi_mod"
    #
    "dm_mod"
    #
    "ufshcd-core"
    "ufs-qcom"
    "phy-qcom-qmp-ufs"
    #
    #    "panel_samsung_s6e3fc2x01"
    #
    #    "simpledrm"
    #    "msm"
    #    "gpucc_sdm845"
    #    "dispcc_sdm845"
    #    "clk-qcom"
    #
    #    "qcom_glink_smem"
    #    "spi-geni-qcom"
    #    "icc-osm-l3"
    #    "qrtr-smd"
    #    "qcom-pon"
    #    "rmtfs_mem"
    #    "drm_mipi_dsi"
  ];

  #  boot.extraModprobeConfig = ''
  #    softdep msm pre: panel-samsung-sofef00 gpucc_sdm845 dispcc_sdm845
  #  '';

  boot.kernelParams = [
    #    "iommu=soft"
    "clk_ignore_unused"
    "pd_ignore_unused"
    "arm64.nopauth"
    "console=ttyMSM0,115200n8"
    "console=tty0"

    "rd.systemd.default_standard_output=kmsg+console"
    "rd.systemd.default_standard_error=kmsg+console"
    "rd.systemd.journald.forward_to_console=1"
    "rd.systemd.log_target=console"
    "rd.systemd.journald.forward_to_console=1"

    #    "dtb=/${config.hardware.deviceTree.name}"
  ];

  hardware.deviceTree.name = "qcom/sdm845-oneplus-fajita.dtb";

  boot.consoleLogLevel = 8;

  hardware.firmware = [
    firmware2
    pkgs.linux-firmware
  ];
  #hardware.firmware = lib.mkForce [];

  #  hardware.deviceTree.overlays = [
  #    {
  #      name = "enable-usb";
  #      dtsText = ''
  #        /dts-v1/;
  #        /plugin/;
  #        / {
  #          compatible = "oneplus,fajita";
  #          fragment@0 {
  #            target = <&usb_1_dwc3>;
  #            __overlay__ {
  #              dr_mode = "host";
  #            };
  #          };
  #        };
  #      '';
  #    }
  #  ];

  # Maybe we should throw an assertion in nixpkgs if you are using systemd-boot
  # but you don't use vmlinuz.efi/zinstall like this
  nixpkgs.hostPlatform = lib.recursiveUpdate (lib.systems.elaborate "aarch64-linux") {
    linux-kernel.target = "vmlinuz.efi";
    linux-kernel.installTarget = "zinstall";
  };
  #  boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelPackages = kernelPkgs.linuxPackagesFor oneplusKernel;
  boot.kernelPatches = [
    {
      name = "disable-stuff";
      patch = null;
      structuredExtraConfig = {
        # Crashes the kernel
        #         QCOM_IPA = lib.mkForce lib.kernel.no;
        #         ATH10K_AHB = lib.mkForce lib.kernel.yes;
        #         CRYPTO_DEV_QCE = lib.mkForce lib.kernel.no;
        #         CRYPTO_DEV_QCOM_RNG = lib.mkForce lib.kernel.no;
        #        #TEGRA_BPMP = lib.mkForce lib.kernel.no;
        #         SCHED_CLASS_EXT = lib.mkForce lib.kernel.no;
        #        #DRM_MSM_KMS = lib.mkForce lib.kernel.no;
        #        #DRM_MSM_KMS_FBDEV = lib.mkForce lib.kernel.no;
        #        #QCOM_PD_MAPPER = lib.mkForce lib.kernel.module;
        #        #USB_DWC3_GENERIC_PLAT = lib.mkForce lib.kernel.module;
        #        #INTERCONNECT_QCOM_MSM8953 = lib.mkForce lib.kernel.module;
        #        #INTERCONNECT_QCOM_SM6350 = lib.mkForce lib.kernel.module;
        #        #MSM_GCC_8953 = lib.mkForce lib.kernel.module;
        #        #PCI_DYNAMIC_OF_NODES = lib.mkForce lib.kernel.module;
        #        #PCI_PWRCTRL_SLOT = lib.mkForce lib.kernel.module;
        #        #PINCTRL_IMX_SCMI = lib.mkForce lib.kernel.module;
        #        #PM_DEVFREQ_EVENT = lib.mkForce lib.kernel.no;
        #        #RESET_TI_SYSCON = lib.mkForce lib.kernel.module;
        #        #SM_GCC_6350 = lib.mkForce lib.kernel.module;
        #        #USB_ONBOARD_DEV_USB5744 = lib.mkForce lib.kernel.no;
        #        #USB_XHCI_SIDEBAND = lib.mkForce lib.kernel.no;
        #        #SOUND = lib.mkForce lib.kernel.yes;
        #        #SND_TIMER = lib.mkForce lib.kernel.yes;
        #        #SND_SOC_SOF_OF = lib.mkForce lib.kernel.yes;
        #        #SND_SOC_SDCA_OPTIONAL = lib.mkForce lib.kernel.yes;
        #        #SND_SOC_I2C_AND_SPI = lib.mkForce lib.kernel.yes;
        #        #SND_SOC_HDMI_CODEC = lib.mkForce lib.kernel.yes;
        #        #SND_SOC = lib.mkForce lib.kernel.yes;
        #        #SND_PCM = lib.mkForce lib.kernel.yes;
        #        #SND_COMPRESS_OFFLOAD = lib.mkForce lib.kernel.yes;
        #        #SND = lib.mkForce lib.kernel.yes;
        #        #CRYPTO_MD5 = lib.mkForce lib.kernel.yes;
        #        #SOC_TEGRA_POWERGATE_BPMP = lib.mkForce lib.kernel.no;
        #        #TOUCHSCREEN_FTM4 = lib.mkForce lib.kernel.no;
        #        #SND_SOC_MAX98512 = lib.mkForce lib.kernel.no;
        #        #SDM_DISPCC_845  = lib.mkForce lib.kernel.module;
        #        #SDM_GPUCC_845  = lib.mkForce lib.kernel.module;
        #        #ARCH_RENESAS = lib.mkForce lib.kernel.no;
        #        #ARCH_ROCKCHIP = lib.mkForce lib.kernel.no;
        #        #ROCKCHIP_DW_HDMI_QP = lib.mkForce lib.kernel.unset;
        #        #IMX_REMOTEPROC = lib.mkForce lib.kernel.no;
      };
    }
  ];

}
