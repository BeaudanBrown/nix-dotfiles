{
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

  # Expose nixpkgs-unstable as pkgs.unstable.* via overlay.
  # Individual modules add packages to this namespace by appending their own overlays.
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import nixpkgsUnstable {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    })
  ];
}
