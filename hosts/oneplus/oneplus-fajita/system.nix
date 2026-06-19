{
  lib,
  config,
  pkgs,
  ...
}:
let
  oneplusForceReboot = pkgs.writeShellApplication {
    name = "reboot";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -eu

      if [ "$(id -u)" != 0 ]; then
        exec /run/wrappers/bin/sudo -n /run/current-system/sw/bin/reboot "$@"
      fi

      echo "=== ONEPLUS SYSRQ REBOOT $(date -Ins) args: $* ===" >/dev/kmsg || true
      sync
      echo s >/proc/sysrq-trigger
      sleep 2
      echo u >/proc/sysrq-trigger
      sleep 2
      echo b >/proc/sysrq-trigger
      sleep 30
      echo "SysRq reboot did not complete" >&2
      exit 1
    '';
  };
  oneplusForceShutdown = pkgs.writeShellApplication {
    name = "shutdown";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -eu

      if [ "$(id -u)" != 0 ]; then
        exec /run/wrappers/bin/sudo -n /run/current-system/sw/bin/shutdown "$@"
      fi

      action=poweroff
      for arg in "$@"; do
        case "$arg" in
          -r|--reboot)
            action=reboot
            ;;
          -c|--cancel)
            echo "oneplus shutdown wrapper does not support cancelling scheduled shutdowns" >&2
            exit 1
            ;;
        esac
      done

      echo "=== ONEPLUS SYSRQ SHUTDOWN $(date -Ins) action: $action args: $* ===" >/dev/kmsg || true
      sync
      echo s >/proc/sysrq-trigger
      sleep 2
      echo u >/proc/sysrq-trigger
      sleep 2
      if [ "$action" = reboot ]; then
        echo b >/proc/sysrq-trigger
      else
        echo o >/proc/sysrq-trigger
      fi
      sleep 30
      echo "SysRq $action did not complete" >&2
      exit 1
    '';
  };
  oneplusSaveClock = pkgs.writeShellApplication {
    name = "oneplus-save-clock";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -eu
      install -d -m 0755 /var/lib/oneplus-time-seed
      touch /var/lib/oneplus-time-seed/stamp
    '';
  };
  oneplusRestoreClock = pkgs.writeShellApplication {
    name = "oneplus-restore-clock";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -eu

      stamp=/var/lib/oneplus-time-seed/stamp
      if [ ! -e "$stamp" ]; then
        exit 0
      fi

      saved_epoch=$(stat -c %Y "$stamp")
      current_epoch=$(date -u +%s)
      if [ "$current_epoch" -lt "$saved_epoch" ]; then
        date -u -s "@$saved_epoch"
      fi
    '';
  };
  oneplusPstoreStatus = pkgs.writeShellApplication {
    name = "oneplus-pstore-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.file
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      set -eu

      echo "-- active pstore backend --"
      for f in /sys/module/pstore/parameters/backend /sys/module/pstore/parameters/compress /sys/module/pstore/parameters/kmsg_bytes; do
        if [ -r "$f" ]; then
          printf '%s=' "$f"
          cat "$f"
        fi
      done

      echo "-- current /sys/fs/pstore --"
      if [ -d /sys/fs/pstore ]; then
        ls -la /sys/fs/pstore
      else
        echo "/sys/fs/pstore is not mounted"
      fi

      echo "-- archived systemd-pstore files --"
      if [ -d /var/lib/systemd/pstore ]; then
        ls -lah /var/lib/systemd/pstore
        find /var/lib/systemd/pstore -maxdepth 1 -type f -print0 \
          | xargs -0 -r file
      else
        echo "/var/lib/systemd/pstore does not exist"
      fi

      echo "-- recent pstore/ramoops kernel messages --"
      dmesg -T 2>/dev/null \
        | grep -Ei 'pstore|ramoops|persistent|oops|panic|watchdog|hard lockup|soft lockup' \
        | tail -80 || true
    '';
  };
  oneplusHangSnapshot = pkgs.writeShellApplication {
    name = "oneplus-hang-snapshot";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.procps
      pkgs.util-linux
    ];
    text = ''
      set -eu

      out_dir=/var/log/oneplus-hang-watch
      log="$out_dir/snapshots.log"
      tmp="$out_dir/snapshots.tmp"
      install -d -m 0755 "$out_dir"

      {
        echo "===== oneplus hang snapshot $(date -Ins) ====="
        printf 'boot_id='; cat /proc/sys/kernel/random/boot_id 2>/dev/null || true
        printf 'uptime='; cat /proc/uptime 2>/dev/null || true
        printf 'loadavg='; cat /proc/loadavg 2>/dev/null || true

        echo "-- memory --"
        grep -E '^(MemTotal|MemAvailable|MemFree|Buffers|Cached|SwapTotal|SwapFree|SReclaimable|SUnreclaim):' /proc/meminfo 2>/dev/null || true

        echo "-- pressure --"
        for f in /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io; do
          if [ -r "$f" ]; then
            printf '%s: ' "$f"
            tr '\n' ' ' < "$f"
            echo
          fi
        done

        echo "-- drm status --"
        for f in /sys/class/drm/card*-*/status /sys/class/drm/card*-*/enabled /sys/class/drm/card*-*/modes /sys/class/drm/card*-*/dpms; do
          if [ -e "$f" ]; then
            printf '%s=' "$f"
            tr '\n' ' ' < "$f" 2>/dev/null || true
            echo
          fi
        done

        echo "-- dmesg display/hang tail --"
        dmesg -T 2>/dev/null \
          | grep -Ei 'drm|dpu|msm|adreno|gpu|smmu|vblank|encoder|watchdog|rcu|blocked|oom|panic|memory pressure|hung' \
          | tail -80 || true

        echo "-- largest processes --"
        ps -eo pid,ppid,stat,comm,%cpu,%mem,rss,args --sort=-rss 2>/dev/null | head -30 || true
        echo
      } >> "$log"

      size=$(stat -c %s "$log" 2>/dev/null || echo 0)
      if [ "$size" -gt 4194304 ]; then
        tail -n 3000 "$log" > "$tmp"
        mv "$tmp" "$log"
      fi
    '';
  };
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
    ./ui/hyprland.nix
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
  boot = {
    kernelParams = lib.mkForce [
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

      # Prefer the reserved-memory ramoops backend for post-crash evidence. The
      # device tree provides 4 MiB at ramoops@ac300000; keep EFI pstore from
      # racing the useful backend if module load ordering changes.
      "pstore.backend=ramoops"
    ];

    # Make `/proc/sysrq-trigger` fully available for the local reboot/poweroff
    # wrappers below. SysRq s/u/b avoids the broken orderly qcom_q6v5_mss stop
    # path and remounts filesystems read-only before emergency reboot.
    kernel.sysctl = {
      "kernel.sysrq" = 1;

      # Keep random hard-freeze evidence in the journal instead of waiting for a
      # manual repro. These log warnings but do not panic/reboot the phone.
      "kernel.hung_task_timeout_secs" = 60;
      "kernel.hung_task_check_interval_secs" = 30;
      "kernel.hung_task_panic" = 0;
      "kernel.watchdog" = 1;
    };
  };
  custom.atticCache.upload.enable = true;

  # The kernel currently exposes WCN3990 Bluetooth as hci0, but the OnePlus
  # host does not import the work-root blueman module that enables BlueZ.
  # Enable the system Bluetooth service here so userspace can see the adapter.
  hardware.bluetooth.enable = true;

  # Allow ticket-scoped agent UI smoke tests to inject one-shot pointer/key
  # events through the ydotool flake helpers. Keep this OnePlus-local because it
  # grants uinput-style control to members of the ydotool group.
  programs.ydotool.enable = true;
  users.users.${config.hostSpec.username}.extraGroups = [ config.programs.ydotool.group ];

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

    # Let userspace handle the phone's power key instead of treating a short
    # press as a shutdown request. Long press remains available as an emergency
    # poweroff path when the kernel/input stack exposes it separately.
    logind.settings.Login = {
      HandlePowerKey = "ignore";
      HandlePowerKeyLongPress = "poweroff";
    };

    journald.extraConfig = ''
      Storage=persistent
      SystemMaxUse=256M
      RuntimeMaxUse=64M
    '';
  };

  # The PMIC RTC currently persists/returns a 1970-era clock. Keep a monotonic
  # userspace timestamp seed so early boot is at worst minutes behind the last
  # synced runtime instead of decades behind, then let timesyncd correct it once
  # Wi-Fi is online. Certificate-sensitive services should still wait for
  # time-sync.target when practical.
  systemd = {
    additionalUpstreamSystemUnits = [ "systemd-time-wait-sync.service" ];

    services = {
      systemd-time-wait-sync.wantedBy = [ "sysinit.target" ];

      oneplus-time-restore = {
        description = "Restore OnePlus clock from userspace timestamp seed";
        wantedBy = [ "sysinit.target" ];
        before = [
          "sysinit.target"
          "time-set.target"
        ];
        after = [
          "local-fs.target"
          "systemd-remount-fs.service"
        ];
        unitConfig = {
          DefaultDependencies = false;
          ConditionPathExists = "/var/lib/oneplus-time-seed/stamp";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${oneplusRestoreClock}/bin/oneplus-restore-clock";
        };
      };

      oneplus-time-save = {
        description = "Save OnePlus clock timestamp seed";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${oneplusSaveClock}/bin/oneplus-save-clock";
        };
      };

      oneplus-hang-snapshot = {
        description = "Record bounded OnePlus hang-debug snapshots";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${oneplusHangSnapshot}/bin/oneplus-hang-snapshot";
        };
      };

      tailscaled = lib.mkIf config.services.tailscale.enable {
        wants = [ "time-sync.target" ];
        after = [ "time-sync.target" ];
      };
    };

    timers = {
      oneplus-time-save = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "15min";
          Persistent = true;
        };
      };

      oneplus-hang-snapshot = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "30s";
          AccuracySec = "1s";
          Persistent = false;
        };
      };
    };
  };

  # Override systemd's normal reboot/shutdown frontends on this phone. Normal
  # orderly shutdown stops qcom_q6v5_mss (4080000.remoteproc), which currently
  # hangs/crashdumps the device. `systemctl --force --force` avoids that stop
  # path but leaves userspace running while UFS goes away, causing noisy I/O
  # errors. Use SysRq sync/remount-ro/reboot-or-poweroff instead so `sudo reboot`
  # and `sudo shutdown now` remain the agent-safe iteration commands.
  environment.systemPackages = lib.mkBefore [
    (lib.hiPrio oneplusForceReboot)
    (lib.hiPrio oneplusForceShutdown)
    oneplusPstoreStatus

    # Keep camera/media graph inspection tools available on-device. The phone
    # exposes CAMSS sensors and actuator subdevices directly through V4L2/media;
    # these tools let follow-up work distinguish sensor capture from OIS/actuator
    # failures without rebuilding the system just to inspect the graph.
    pkgs.libcamera
    pkgs.v4l-utils
  ];

  environment.sessionVariables.ALSA_CONFIG_UCM2 = "${oneplusUcm}/share/alsa/ucm2";

  # Be explicit about archiving pstore records to disk and clearing the tiny
  # reserved RAM area after systemd has copied it. This prevents stale/corrupt
  # ramoops slots from being re-archived forever and keeps the next crash record
  # room clean.
  environment.etc."systemd/pstore.conf".text = ''
    [PStore]
    Storage=external
    Unlink=yes
  '';

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
    # Do not start this automatically at login. Generation 71 proved that a
    # boot-time module-alsa-source load gives the desired app-visible source
    # shape but poisons/locks the lower-level capture path into exact-zero
    # samples. Keep it as an explicit debug/manual service while retracing the
    # clean speaker-only boot state.
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
