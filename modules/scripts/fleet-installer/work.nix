{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleetInstaller = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.fleet-installer;
in
{
  environment.systemPackages = [ fleetInstaller ];

  sops.secrets."headscale/installer_pre_auth" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    path = "/run/secrets/headscale/installer_pre_auth";
    mode = "0400";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };
}
