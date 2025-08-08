{
  config,
  ...
}:
{
  home-manager.users.${config.hostSpec.username}.programs.feh = {
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
}
