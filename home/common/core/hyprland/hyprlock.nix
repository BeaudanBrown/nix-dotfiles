{ config, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 2;
        no_fade_out = true;
      };

      background = [{
        monitor = "";
        color = "rgb(282828)";
        path = "${config.stylix.image}";
      }];

      input-field = [{
        monitor = "";
        size = "300, 50";
        outline_thickness = 0;
        inner_color = "rgb(458588)";
        font_color  = "rgb(282828)";
        fail_color  = "rgb(cc241d)";
        fade_on_empty = false;
        placeholder_text = ''Password:'';
        dots_spacing = 0.3;
        dots_center = true;
        position = "0, -440";
      }];

      label = [{
        monitor = "";
        text = "$TIME";
        font_size = 50;
        color = "rgb(83a598)";
        position = "0, 440";
        valign = "center";
        halign = "center";
      }];
    };
  };
}
