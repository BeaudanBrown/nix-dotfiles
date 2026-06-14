{
  lib,
  config,
  pkgs,
  ...
}:
let
  oneplusUcm = pkgs.runCommand "oneplus-alsa-ucm-conf" { } ''
    mkdir -p $out/share/alsa
    cp -r ${pkgs.alsa-ucm-conf}/share/alsa/ucm2 $out/share/alsa/ucm2
    chmod -R u+w $out/share/alsa/ucm2

    cat > $out/share/alsa/ucm2/Qualcomm/sdm845/OnePlus6T.conf <<'EOF'
    Syntax 3

    SectionUseCase."HiFi" {
      File "/Qualcomm/sdm845/OnePlus6T-HiFi.conf"
      Comment "HiFi quality Music."
    }
    EOF

    cat > $out/share/alsa/ucm2/Qualcomm/sdm845/OnePlus6T-HiFi.conf <<'EOF'
    SectionVerb {
      EnableSequence [
        cset "name='QUAT_MI2S_RX Audio Mixer MultiMedia1' 1"
      ]

      DisableSequence [
        cset "name='QUAT_MI2S_RX Audio Mixer MultiMedia1' 0"
      ]

      Value {
        TQ "HiFi"
      }
    }

    SectionDevice."Speaker" {
      Comment "Speaker playback"

      Value {
        PlaybackPriority 100
        PlaybackPCM "hw:O6T,0"
      }
    }

    SectionDevice."Mic" {
      Comment "Microphone capture"

      Value {
        CapturePriority 100
        CapturePCM "hw:O6T,0"
      }
    }
    EOF

    ln -sf ../../Qualcomm/sdm845/OnePlus6T.conf \
      $out/share/alsa/ucm2/conf.d/sdm845/oneplus-OnePlus6T.conf

    mkdir -p $out/share/alsa/ucm2/O6T
    ln -sf ../Qualcomm/sdm845/OnePlus6T.conf \
      $out/share/alsa/ucm2/O6T/O6T.conf
  '';
in
{
  imports = [
    ./hardware/qualcomm-services.nix
    ./hardware/sdm845.nix
    ./image/repart.nix
    ./networking/ssh.nix
    ./networking/wireless.nix
    ./ui/greetd.nix
    ./ui/niri.nix
    # ./ui/phosh.nix
  ];
  boot.loader = {
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = false;
    };

    systemd-boot = {
      enable = true;
      configurationLimit = lib.mkForce 10;
      extraFiles = {
        "EFI/BOOT/BOOTAA64.EFI" = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
        "EFI/systemd/systemd-bootaa64.efi" =
          "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
      };
    };
  };
  # Keep the phone on the known-good boot argument shape. The common desktop
  # boot module adds PC-oriented parameters that are unnecessary here.
  boot.kernelParams = lib.mkForce [
    "console=ttyGS0,115200"
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
    "root=fstab"
    "loglevel=8"
    "lsm=landlock,yama,bpf"
  ];
  services = {
    dbus = {
      # Test dbus-broker on the phone through a booted generation rather than a
      # live switch, since changing implementations is blocked by switch inhibitors.
      implementation = "broker";
      packages = [
        config.systemd.package
      ];
    };

    upower.enable = true;
  };

  environment.sessionVariables.ALSA_CONFIG_UCM2 = "${oneplusUcm}/share/alsa/ucm2";

  systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = "${oneplusUcm}/share/alsa/ucm2";

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemd-run";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # The USB gadget serial getty on ttyGS0 holds/contends for /dev/console's
  # flock. That makes `systemd-run --pipe` from a PTY block in the transient
  # service child, which in turn breaks nixos-rebuild-ng. Keep the hardware
  # UART getty on ttyMSM0 for serial rescue, but do not start the USB getty.
  systemd.services."serial-getty@ttyGS0".enable = false;

  nix = {
    buildMachines = lib.mkForce [ ];
    distributedBuilds = lib.mkForce false;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192;
    }
  ];

  system.stateVersion = "25.11";
}
