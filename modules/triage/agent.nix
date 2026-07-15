{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.devenv
    pkgs.python3
  ];
}
