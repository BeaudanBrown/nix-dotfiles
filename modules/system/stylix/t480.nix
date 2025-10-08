{ lib, ... }:
{
  stylix = {
    fonts = {
      sizes = lib.mkForce {
        applications = 13;
        terminal = 11.5;
        popups = 17;
      };
    };
  };
}
