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
}
