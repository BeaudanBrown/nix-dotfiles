{ config, lib, ... }:
let
  secretName = "kdeconnect/${config.networking.hostName}";
in
{
  hmModules.primary = [
    (
      { config, ... }:
      {
        sops.secrets.${secretName} = {
          sopsFile = lib.custom.sopsFileForModule __curPos.file;
          path = "${config.home.homeDirectory}/.config/kdeconnect/trusted_devices";
          mode = "0644";
        };
      }
    )
  ];
}
