{
  pkgs,
  config,
  lib,
  ...
}:
{
  sops.secrets.bottom_mac = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };
  environment.systemPackages = with pkgs; [
    (writeShellApplication {
      name = "bottom_wol";
      excludeShellChecks = [ "SC2029" ];
      text = ''
        mac_address=$(cat ${config.sops.secrets.bottom_mac.path})
        ssh brick "wakeonlan '$mac_address'"
      '';
    })
  ];
}
