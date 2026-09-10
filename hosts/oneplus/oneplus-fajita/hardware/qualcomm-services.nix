{ pkgs, ... }:
let
  # Android's tqftpserv accepts a few firmware path shapes that upstream Linux
  # tqftpserv rejects. The WCN/GNSS stack on this device asks for
  # /readonly/vendor/firmware{_mnt}/... paths during bring-up; serve those from
  # the normal Linux firmware tree and keep /readwrite persistent instead of in
  # /tmp so remote filesystem state survives reboots.
  oneplusTqftpserv = pkgs.unstable.tqftpserv.overrideAttrs (_old: {
    postPatch = ''
            substituteInPlace translate.c \
              --replace-fail '"/tmp/tqftpserv"' '"/var/lib/tqftpserv"'

            substituteInPlace translate.c \
              --replace-fail '"/lib/firmware/"' '"/run/current-system/firmware/"'

            substituteInPlace translate.c \
              --replace-fail \
                'int translate_open(const char *path, int flags)
      {' \
                'static int try_android_firmware_path(const char *prefix, const char *file)
      {
      	char path[PATH_MAX];

      	if (strlen(FIRMWARE_BASE) + strlen(prefix) + strlen(file) + 1 > sizeof(path))
      		return -1;

      	strcpy(path, FIRMWARE_BASE);
      	strcat(path, prefix);
      	strcat(path, file);

      	return open_maybe_compressed(path);
      }

      static int translate_android_firmware_path(const char *file)
      {
      	const char *base;
      	int fd;

      	/* Android RFS symlinks expose /vendor/firmware{_mnt}/image as the modem
      	 * firmware root. Preserve subdirectories first because modem_pr/mcfg paths
      	 * are nested, then fall back to basename lookup for simple requests such as
      	 * wlanmdsp.mbn.
      	 */
      	fd = try_android_firmware_path("qcom/sdm845/OnePlus/fajita/", file);
      	if (fd >= 0 || errno != ENOENT)
      		return fd;

      	fd = try_android_firmware_path("qcom/sdm845/OnePlus/enchilada/", file);
      	if (fd >= 0 || errno != ENOENT)
      		return fd;

      	fd = try_android_firmware_path("qcom/sdm845/", file);
      	if (fd >= 0 || errno != ENOENT)
      		return fd;

      	base = strrchr(file, 47);
      	file = base ? base + 1 : file;

      	return try_android_firmware_path("qcom/sdm845/", file);
      }

      int translate_open(const char *path, int flags)
      {'

            substituteInPlace translate.c \
              --replace-fail \
                'else if (!strncmp(path, READWRITE_PATH, strlen(READWRITE_PATH)))' \
                'else if (!strncmp(path, "/readonly/vendor/firmware_mnt/image/", strlen("/readonly/vendor/firmware_mnt/image/")))
      		return translate_android_firmware_path(path + strlen("/readonly/vendor/firmware_mnt/image/"));
      	else if (!strncmp(path, "/readonly/vendor/firmware/", strlen("/readonly/vendor/firmware/")))
      		return translate_android_firmware_path(path + strlen("/readonly/vendor/firmware/"));
      	else if (!strncmp(path, "/vendor/rfs/apq/gnss/readonly/firmware/image/", strlen("/vendor/rfs/apq/gnss/readonly/firmware/image/")))
      		return translate_android_firmware_path(path + strlen("/vendor/rfs/apq/gnss/readonly/firmware/image/"));
      	else if (!strncmp(path, "/vendor/rfs/apq/gnss/readonly/vendor/firmware/", strlen("/vendor/rfs/apq/gnss/readonly/vendor/firmware/")))
      		return translate_android_firmware_path(path + strlen("/vendor/rfs/apq/gnss/readonly/vendor/firmware/"));
      	else if (!strncmp(path, "/vendor/rfs/apq/gnss/hlos/", strlen("/vendor/rfs/apq/gnss/hlos/")))
      		return translate_readwrite(path + strlen("/vendor/rfs/apq/gnss/hlos/"), flags);
      	else if (!strncmp(path, "/vendor/rfs/apq/gnss/ramdumps/", strlen("/vendor/rfs/apq/gnss/ramdumps/")))
      		return translate_readwrite(path + strlen("/vendor/rfs/apq/gnss/ramdumps/"), flags);
      	else if (!strncmp(path, "/vendor/rfs/apq/gnss/readwrite/", strlen("/vendor/rfs/apq/gnss/readwrite/")))
      		return translate_readwrite(path + strlen("/vendor/rfs/apq/gnss/readwrite/"), flags);
      	else if (!strncmp(path, "/vendor/rfs/apq/gnss/shared/", strlen("/vendor/rfs/apq/gnss/shared/")))
      		return translate_readwrite(path + strlen("/vendor/rfs/apq/gnss/shared/"), flags);
      	else if (!strncmp(path, "/mnt/vendor/persist/rfs/apq/gnss/", strlen("/mnt/vendor/persist/rfs/apq/gnss/")))
      		return translate_readwrite(path + strlen("/mnt/vendor/persist/rfs/apq/gnss/"), flags);
      	else if (!strncmp(path, "/mnt/vendor/persist/rfs/shared/", strlen("/mnt/vendor/persist/rfs/shared/")))
      		return translate_readwrite(path + strlen("/mnt/vendor/persist/rfs/shared/"), flags);
      	else if (!strncmp(path, READWRITE_PATH, strlen(READWRITE_PATH)))'
    '';
  });

  # OnePlus SDM845 modem firmware asks rmtfs for OEM NV backup paths that
  # upstream rmtfs does not know about. Map those paths to the board's
  # oem_stanvbk/oem_dycnvbk partitions so the modem can read the same EFS/NV
  # partitions Android exposes. The service still runs with -r, so this is
  # read-only.
  oneplusRmtfs = pkgs.unstable.rmtfs.overrideAttrs (_old: {
    postPatch = ''
      # rmtfs verbose logging uses stdout without flushing. Under systemd/journald
      # that becomes block-buffered, which hides boot-time modem RFS requests.
      substituteInPlace rmtfs.c \
        --replace-fail 'vprintf(fmt, ap);' 'vprintf(fmt, ap); fflush(stdout);'

      substituteInPlace storage.c \
        --replace-fail \
          '{ "/boot/modem_fsg", "modem_fsg", "fsg" },' \
          $'{ "/boot/modem_fsg", "modem_fsg", "fsg" },\n\t{ "/boot/modem_fsg_oem_1", "modem_fsg_oem_1", "oem_stanvbk" },\n\t{ "/boot/modem_fsg_oem_2", "modem_fsg_oem_2", "oem_dycnvbk" },\n\t{ "/oem/nvbk/static", "oem_nvbk_static", "oem_stanvbk" },\n\t{ "/oem/nvbk/dynamic", "oem_nvbk_dynamic", "oem_dycnvbk" },'
    '';
  });
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/tqftpserv 0700 root root -"
    "d /var/lib/tqftpserv/ota_firewall 0700 root root -"
    "f /var/lib/tqftpserv/ota_firewall/ruleset 0600 root root -"
    "f /var/lib/tqftpserv/mcfg.tmp 0600 root root -"
    "f /var/lib/tqftpserv/server_check.txt 0600 root root -"
    "d /var/lib/tqftpserv/ramdumps 0700 root root -"
  ];

  systemd.services.tqftpserv = {
    description = "Qualcomm QRTR TFTP services (tqftpserv)";
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${oneplusTqftpserv}/bin/tqftpserv";
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

    # Do not restart rmtfs during `nixos-rebuild switch`: once the modem remoteproc
    # is up, removing its remote filesystem service can crashdump the phone. Boot
    # into changed rmtfs configs instead.
    restartIfChanged = false;

    serviceConfig = {
      ExecStart = "${oneplusRmtfs}/bin/rmtfs -r -P -s -v";
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
    unitConfig.ConditionPathExists = [
      "!/dev/fastrpc-sdsp"
      "/dev/fastrpc-adsp"
    ];

    serviceConfig = {
      ExecStart = "${pkgs.unstable.hexagonrpc}/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s";
      Restart = "on-failure";
      RestartSec = "3s";
      User = "root";
      Group = "root";
    };
  };
}
