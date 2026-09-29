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
    # Raw token belonging to beau; both profiles intentionally use this credential.
    # Project bindings currently supply defaults, not enforced access restrictions.
  };
  hm.primary.xdg.configFile."vikunja-agent/full.json".text = builtins.toJSON {
    baseUrl = "https://todo.bepis.lol";
    tokenFile = config.sops.secrets."vikunja/api-token".path;
  };
}
