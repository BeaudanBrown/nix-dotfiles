{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.joplin-desktop
  ];
}
