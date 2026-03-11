{
  lib,
  ...
}:
{
  hm.all.xdg = {
    userDirs = {
      enable = lib.mkForce false;
    };
  };
}
