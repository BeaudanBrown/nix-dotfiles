{ nixpkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "-d";
    };

    settings = {
      experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
      trusted-users = [ "root" "@wheel" ];
    };
  };
}
