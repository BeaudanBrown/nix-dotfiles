{
  config,
  lib,
  ...
}:
{
  imports = [ ./agent-host.nix ];

  sops.secrets."vikunja/api-token" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Raw token for a separate account shared only into approved software projects.
  };
  sops.secrets."vikunja/full-api-token" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Separate full-access account/token, explicitly selected with init --profile full.
  };
  hm.primary.xdg.configFile."vikunja-agent/full.json".text = builtins.toJSON {
    baseUrl = "https://todo.bepis.lol";
    tokenFile = config.sops.secrets."vikunja/full-api-token".path;
  };
}
