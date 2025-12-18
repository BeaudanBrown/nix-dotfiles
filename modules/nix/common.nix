{ config, ... }:
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
    mode = "0440";
  };

  nix.extraOptions = ''
    !include ${config.sops.secrets.nix-github-access.path}
  '';
}
