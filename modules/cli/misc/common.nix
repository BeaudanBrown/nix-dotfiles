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
    ncdu
    lsof
    curl
    procps
  ];
}
