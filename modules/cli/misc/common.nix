{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    jq
    ripgrep
    unzip
    gnumake
    nh
    nix-fast-build
    ncdu
    lsof
    curl
    procps
  ];
}
