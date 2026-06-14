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

      Include.wcde.File "/codecs/wcd934x/DefaultEnableSeq.conf"
      Include.wcdd {
        File "/codecs/wcd934x/DefaultDisableSeq.conf"
        Before.DisableSequence "0"
      }

      DisableSequence [
        cset "name='QUAT_MI2S_RX Audio Mixer MultiMedia1' 0"
      ]

      Value {
        TQ "HiFi"
        PlaybackCTL "hw:O6T"
        CaptureCTL "hw:O6T"
      }
    }

    SectionDevice."Speaker" {
      Comment "Speaker playback"

      Include.wcdspke.File "/codecs/wcd934x/SpeakerEnableSeq.conf"
      Include.wcdspkd.File "/codecs/wcd934x/SpeakerDisableSeq.conf"

      EnableSequence [
        cset "name='RX0 Digital Volume' 120"
        cset "name='RX1 Digital Volume' 120"
        cset "name='RX7 Digital Volume' 120"
        cset "name='RX8 Digital Volume' 120"
      ]

      Value {
        PlaybackPriority 100
        PlaybackPCM "hw:O6T,0"
        PlaybackChannels 2
      }
    }

    EOF

    cat > $out/share/alsa/ucm2/module/snd_soc_sdm845.conf <<'EOF'
    Syntax 3

    SectionUseCase."HiFi" {
      File "/Qualcomm/sdm845/OnePlus6T-HiFi.conf"
      Comment "HiFi quality Music."
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

  systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = "${oneplusUcm}/share/alsa/ucm2";
  systemd.user.services.wireplumber = {
    environment.ALSA_CONFIG_UCM2 = "${oneplusUcm}/share/alsa/ucm2";
    unitConfig = {
      Requires = [ "oneplus-audio-route.service" ];
      After = [ "oneplus-audio-route.service" ];
    };
  };

  systemd.user.services.oneplus-audio-route = {
    description = "Initialize OnePlus 6T audio route";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      Environment = "ALSA_CONFIG_UCM2=${oneplusUcm}/share/alsa/ucm2";
      ExecStart = pkgs.writeShellScript "oneplus-audio-route" ''
        set -eu

        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
          if ${pkgs.alsa-utils}/bin/alsaucm -c O6T set _verb HiFi set _enadev Speaker; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done

        exit 1
      '';
    };
  };

  systemd.user.services.oneplus-mic-source = {
    description = "Expose OnePlus 6T bottom microphone through PipeWire Pulse";
    wantedBy = [ "default.target" ];
    after = [
      "oneplus-audio-route.service"
      "pipewire-pulse.service"
      "wireplumber.service"
    ];
    wants = [
      "oneplus-audio-route.service"
      "pipewire-pulse.service"
      "wireplumber.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "oneplus-mic-source" ''
        set -eu

        if ${pkgs.pulseaudio}/bin/pactl list modules short | ${pkgs.gnugrep}/bin/grep -q 'module-alsa-source.*oneplus_bottom_mic'; then
          exit 0
        fi

        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='MultiMedia2 Mixer SLIMBUS_0_TX' 1
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='AIF1_CAP Mixer SLIM TX7' 1
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='CDC_IF TX7 MUX' DEC7
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='ADC MUX7' AMIC
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='AMIC MUX7' ADC4
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='AMIC4_5 SEL' AMIC4
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='ADC4 Volume' 12
        ${pkgs.alsa-utils}/bin/amixer -c O6T cset name='DEC7 Volume' 84

        ${pkgs.pulseaudio}/bin/pactl load-module module-alsa-source \
          device=hw:O6T,1 \
          source_name=oneplus_bottom_mic \
          source_properties=device.description=OnePlus_Bottom_Mic \
          format=s16le \
          rate=48000 \
          channels=1

        ${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.platform-sound.HiFi__Speaker__sink
        ${pkgs.pulseaudio}/bin/pactl set-default-source oneplus_bottom_mic
      '';
    };
  };

  services.pipewire.wireplumber.extraConfig."oneplus-alsa"."monitor.alsa.rules" = [
    {
      matches = [
        {
          "device.name" = "alsa_card.platform-sound";
        }
      ];
      actions.update-props = {
        "api.alsa.use-acp" = true;
        "api.alsa.use-ucm" = true;
        "api.alsa.split-enable" = false;
        "api.acp.hidden-profiles" = "pro-audio";
      };
    }
    {
      matches = [
        {
          "node.name" = "~alsa_input.platform-sound.capture.*";
        }
        {
          "node.name" = "~alsa_output.platform-sound.playback.[1-6].*";
        }
      ];
      actions.update-props."node.disabled" = true;
    }
    {
      matches = [
        {
          "node.name" = "alsa_output.platform-sound.playback.0.0";
        }
      ];
      actions.update-props = {
        "audio.format" = "S16LE";
        "audio.rate" = 48000;
        "audio.channels" = 2;
        "audio.position" = [
          "FL"
          "FR"
        ];
        "node.description" = "OnePlus Speaker";
        "node.nick" = "Speaker";
        "node.link-group" = "oneplus-speaker";
      };
    }
    {
      matches = [
        {
          "api.alsa.path" = "hw:O6T,0";
          "media.class" = "Audio/Sink";
        }
      ];
      actions.update-props = {
        "audio.format" = "S16LE";
        "audio.rate" = 48000;
        "audio.channels" = 2;
        "audio.position" = [
          "FL"
          "FR"
        ];
      };
    }
  ];

  # Temporary bring-up/debug mode for this phone: allow the agent/user in wheel
  # to inspect and iterate across boot cycles without an interactive password.
  # Remove this once the OnePlus system is stable overall.
  security.sudo.wheelNeedsPassword = false;

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
