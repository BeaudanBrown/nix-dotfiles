{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.joplin-desktop
    pkgs.freecad
    pkgs.blender
  ];
}
