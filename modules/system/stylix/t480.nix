{ lib, ... }:
{
  stylix = {
    fonts = {
      sizes = lib.mkForce {
        applications = 13;
        terminal = 11;
        popups = 17;
      };
    };
  };
}
