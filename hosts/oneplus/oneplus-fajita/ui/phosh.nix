# This file is in the gitignore, changes will be ignored. It exists so changes
# can be tested but not committed accidentally.
{ pkgs, lib, config, ... }:
{
  systemd.services.phosh.environment.XDG_PICTURES_DIR = "/tmp";

  hardware.graphics.enable = true;
  services.xserver.desktopManager.phosh = {
    enable = true;
    group = "users";
    user = "beau";
  };
  programs.feedbackd.enable = true;
  programs.calls.enable = true;
  hardware.sensor.iio.enable = true;
  systemd.packages = [ pkgs.stevia ];
  environment.systemPackages = with pkgs; [
    unstable.hexagonrpc
    snapshot
    # Disabled since it uses `olm` which was marked insecure.
    #chatty              # IM and SMS
    snapshot
    epiphany            # Web browser
    stevia
    gnome-console       # Terminal
    git
    vim
    tmux

#    qrtr
#    rmtfs
#    qmic
#    tqftpserv
  ];
  users.users."beau" = {
    isNormalUser = true;
    extraGroups = [
      "dialout"
      "feedbackd"
      "networkmanager"
      "video"
      "wheel"
      "feedbackd"
    ];
  };

  systemd.services.iio-sensor-proxy.serviceConfig.RestrictAddressFamilies = [ "AF_QIPCRTR" "AF_LOCAL" ];
  systemd.services.iio-sensor-proxy.overrideStrategy = "asDropin";

#  systemd.services.hexagonrpcd-adsp-sensorspd = {
#    description = "Daemon to support Qualcomm Hexagon ADSP virtual filesystem for SensorPD";
#    wantedBy = [ "multi-user.target" ];
#    before = [ "suspend.target" ];
#    conflicts = [ "suspend.target" ];
#
#    serviceConfig = {
#      ExecStart = "${pkgs.hexagonrpc}/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s";
#      Restart = "on-failure";
#      # This service shouldn't be run on devices with an SDSP
#      ConditionPathExists = [ "!/dev/fastrpc-sdsp" "/dev/fastrpc-adsp" ];
#      RestartSec = "3s";
#      # maybe use dynamicuser
#      User = "root";
#      Group = "root";
#    };
#  };

#  systemd.services.tqftpserv = {
#    description = "Qualcomm QRTR TFTP services (tqftpserv)";
#    wantedBy = [ "multi-user.target" ];
#    before = [ "network.target" ];
#
#    serviceConfig = {
#      ExecStart = "${pkgs.tqftpserv}/bin/tqftpserv";
#      Restart = "on-failure";
#      RestartSec = "2s";
#      # maybe use dynamicuser
#      User = "root";
#      Group = "root";
#    };
#  };
#  systemd.services.rmtfs = {
#    description = "Qualcomm Remote Filesystem Daemon (rmtfs)";
#    wantedBy = [ "multi-user.target" ];
#    before = [ "network.target" ];
#
#    serviceConfig = {
#      ExecStart = "${pkgs.rmtfs}/bin/rmtfs -r -P -s";
#      Restart = "on-failure";
#      RestartSec = "2s";
#      # maybe use dynamicuser
#      User = "root";
#      Group = "root";
#    };
#  };
  # Maybe not needed because it's in kernel now
  #systemd.services.pd-mapper = {
  #  description = "Qualcomm Protection Domain Mapper (pd-mapper)";
  #  wantedBy = [ "multi-user.target" ];
  #  after = [ "network.target" ];

  #  serviceConfig = {
  #    ExecStart = "${pkgs.pd-mapper}/bin/pd-mapper";
  #    Restart = "on-failure";
  #    RestartSec = "2s";
  #    # maybe use dynamicuser
  #    User = "root";
  #    Group = "root";
  #  };
  #};
#  networking.modemmanager.enable = true;
  services.udev.extraRules = ''
    # iio-sensor-proxy with libssc: accelerometer mount matrix
    SUBSYSTEM=="misc", KERNEL=="fastrpc-*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, -1"
  '';
  nixpkgs.overlays = [ (self: super: {
  }) ];
  systemd.services.qca-bluetooth = let
    script = pkgs.writeShellScript "qca-bluetooth.sh" ''
      set -x
      trap 'sleep 1' DEBUG # Sleep 1 second before every command execution
      export PATH="${lib.makeBinPath (with pkgs; [ config.hardware.bluetooth.package coreutils-full gawk unixtools.script ])}:$PATH"

      SERIAL=$(grep -o "serialno.*" /proc/cmdline | cut -d" " -f1)
      BT_MAC=$(echo "$SERIAL-BT" | sha256sum | awk -v prefix=0200 '{printf("%s%010s\n", prefix, $1)}')
      BT_MAC=$(echo "$BT_MAC" | cut -c1-12 | sed 's/\(..\)/\1:/g' | sed '$s/:$//')

      script -qc "btmgmt --timeout 3 -i hci0 power off"
      script -qc "btmgmt --timeout 3 -i hci0 public-addr \"$BT_MAC\""
    '';
  in {
    description = "Setup the bluetooth interface";
    wantedBy = [ "multi-user.target" "bluetooth.service" ];
    script = toString script;
    serviceConfig = {
      User = "root";
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  security.pam.services.login.updateWtmp = lib.mkForce false;
#  boot.kernelParams = [ "console=ttyGS0,115200" ];
#  boot.kernelPatches = [
#    {
#      name = "disable-stuff";
#      patch = null;
#      structuredExtraConfig = {
#        USB_G_SERIAL = lib.mkForce lib.kernel.yes;
#        U_SERIAL_CONSOLE = lib.mkForce lib.kernel.yes;
#        USB_U_SERIAL = lib.mkForce lib.kernel.yes;
#      };
#    }
#  ];
}
