{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.github-desktop
  ];
}
