{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.unstable.freecad
  ];
}
