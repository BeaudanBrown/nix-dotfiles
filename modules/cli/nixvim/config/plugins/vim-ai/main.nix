{
  config,
  lib,
  ...
}:
{
  sops.secrets.litellm_api = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
  };

  hmModules.primary = [
    (
      { config, ... }:
      {
        sops.secrets.litellm_api = {
          sopsFile = lib.custom.sopsFileForModule __curPos.file;
          path = "${config.home.homeDirectory}/.config/openai.token";
          mode = "0400";
        };
      }
    )
  ];
}
