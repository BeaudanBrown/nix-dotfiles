{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    jq
    htop
    ripgrep
    unzip
    gnumake
    nh
  ];
  environment.shellAliases = import ./aliases.nix { inherit pkgs; };
}
