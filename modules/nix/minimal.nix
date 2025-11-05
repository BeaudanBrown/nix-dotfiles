{
  pkgs,
  nixpkgsStable,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;
  nix = {
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
  };

  _module.args.pkgsStable = import nixpkgsStable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
}
