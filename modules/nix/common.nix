{ config, lib, ... }:
{
  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    settings = {
      substituters = [
        # "https://nix-community.cachix.org/"
        "https://cache.numtide.com"
        "https://digitallyinduced.cachix.org"
      ];
      trusted-public-keys = [
        # "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "digitallyinduced.cachix.org-1:y+wQvrnxQ+PdEsCt91rmvv39qRCYzEgGQaldK26hCKE="
      ];
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
