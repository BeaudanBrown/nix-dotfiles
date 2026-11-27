{
  config,
  pkgs,
  ...
}:
let
  domain = "kindle.bepis.lol";
  portKey = "calibre-web";
  dataDir = "/var/lib/calibre-web";
  libraryDir = "${dataDir}/library";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      tailnet = true;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
    }
  ];

  services.calibre-web = {
    enable = true;
    listen = {
      ip = "127.0.0.1";
      port = config.custom.ports.assigned.${portKey};
    };
    options = {
      calibreLibrary = libraryDir;
      enableBookUploading = true;
    };
  };

  systemd.services.calibre-library-init = {
    description = "Initialize the Calibre library database";
    before = [ "calibre-web.service" ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "calibre-web";
      StateDirectoryMode = "0700";
      User = "calibre-web";
      Group = "calibre-web";
      RemainAfterExit = true;
    };
    script = ''
      export CALIBRE_CONFIG_DIRECTORY=${dataDir}/calibre-config
      ${pkgs.coreutils}/bin/install -d -m 0750 "$CALIBRE_CONFIG_DIRECTORY" ${libraryDir}
      if [ ! -e ${libraryDir}/metadata.db ]; then
        ${config.services.calibre-web.calibrePackage}/bin/calibredb \
          --with-library ${libraryDir} list >/dev/null
        test -f ${libraryDir}/metadata.db || {
          echo "Calibre did not create ${libraryDir}/metadata.db" >&2
          exit 1
        }
      fi
    '';
  };

  systemd.services.calibre-web = {
    requires = [ "calibre-library-init.service" ];
    after = [ "calibre-library-init.service" ];
  };
}
