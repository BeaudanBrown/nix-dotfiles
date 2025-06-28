{ config, ... }:
let
  baseDir = "/pool1/appdata/postgresql";
  dataDir = "${baseDir}/${config.services.postgresql.package.psqlSchema}";
in
{
  # TODO: This isn't allowing me to create the subfolder for some reason
  systemd.tmpfiles.rules = [
    "d ${baseDir} 0750 postgres postgres - -"
    "d ${dataDir} 0750 postgres postgres - -"
  ];

  services.postgresql = {
    inherit dataDir;
    enable = true;
  };
}
