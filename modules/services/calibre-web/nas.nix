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
      User = "calibre-web";
      Group = "calibre-web";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0750 ${libraryDir}
      if [ ! -e ${libraryDir}/metadata.db ]; then
        ${config.services.calibre-web.calibrePackage}/bin/calibredb \
          --with-library ${libraryDir} restore_database --really-do-it
      fi
    '';
  };

  systemd.services.calibre-web = {
    requires = [ "calibre-library-init.service" ];
    after = [ "calibre-library-init.service" ];
  };
}
