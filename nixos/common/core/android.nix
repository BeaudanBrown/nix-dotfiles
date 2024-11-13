{ pkgs, ... }:
{
  programs.adb.enable = true;
  users.users.beau.extraGroups = ["adbusers"];
}
