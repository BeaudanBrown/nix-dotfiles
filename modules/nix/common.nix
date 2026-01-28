{ config, lib, ... }:
{
  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  sops.secrets.nix-github-access = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0440";
  };

  nix.extraOptions = ''
    !include ${config.sops.secrets.nix-github-access.path}
  '';
}
