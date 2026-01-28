{
  config,
  lib,
  ...
}:
{
  sops = {
    # Which secrets to use, get stored by default in /run/secrets/<name>
    secrets = {
      litellm_api = {
        sopsFile = lib.custom.sopsFileForModule __curPos.file;
        path = "${config.hostSpec.home}/.config/openai.token";
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
      };
    };
  };
}
