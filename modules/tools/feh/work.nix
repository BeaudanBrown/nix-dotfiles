{ config, ... }:
{
  hm.programs.feh = {
    enable = true;
    keybindings = {
      prev_img = [
        "h"
        "Left"
      ];
      next_img = [
        "l"
        "Right"
      ];
      zoom_in = "K";
      zoom_out = "J";
    };
  };

  # Ensure keep-zoom-vp is enabled by default via a theme named 'feh'
  hm.home.file.".config/feh/themes" = {
    text = ''
      feh --keep-zoom-vp
    '';
    target = "${config.hostSpec.home}/.config/feh/themes";
  };
}
