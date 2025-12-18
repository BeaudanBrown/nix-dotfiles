{
  pkgs,
  nixpkgsUnstable,
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

  _module.args.pkgsUnstable = import nixpkgsUnstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
}
