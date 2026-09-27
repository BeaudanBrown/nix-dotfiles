{
  config,
  lib,
  pkgs,
  ...
}:
{
  # The managed project owns its tools; no Mealie code is loaded in other Pi projects.
  environment.systemPackages = [ pkgs.nodejs_24 ];

  sops.secrets."mealie/api-token" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
  };

  # Only a path is public. The client reads the token for each request, including
  # after rotation, without putting it into the shell environment or tool inputs.
  hm.primary.xdg.configFile."mealie-agent/config.json".text = builtins.toJSON {
    baseUrl = "https://meals.bepis.lol";
    tokenFile = config.sops.secrets."mealie/api-token".path;
  };
}
