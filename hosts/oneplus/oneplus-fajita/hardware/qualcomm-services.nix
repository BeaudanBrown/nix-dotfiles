{ pkgs, ... }:
{
  systemd.services.tqftpserv = {
    description = "Qualcomm QRTR TFTP services (tqftpserv)";
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.unstable.tqftpserv}/bin/tqftpserv";
      Restart = "on-failure";
      RestartSec = "2s";
      User = "root";
      Group = "root";
    };
  };

  systemd.services.rmtfs = {
    description = "Qualcomm Remote Filesystem Daemon (rmtfs)";
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.unstable.rmtfs}/bin/rmtfs -r -P -s";
      Restart = "on-failure";
      RestartSec = "2s";
      User = "root";
      Group = "root";
    };
  };

  systemd.services.hexagonrpcd-adsp-sensorspd = {
    description = "Qualcomm Hexagon ADSP virtual filesystem daemon for SensorPD";
    wantedBy = [ "multi-user.target" ];
    before = [ "suspend.target" ];
    conflicts = [ "suspend.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.unstable.hexagonrpc}/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s";
      Restart = "on-failure";
      ConditionPathExists = [
        "!/dev/fastrpc-sdsp"
        "/dev/fastrpc-adsp"
      ];
      RestartSec = "3s";
      User = "root";
      Group = "root";
    };
  };
}
