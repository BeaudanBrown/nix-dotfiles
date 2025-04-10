{ ... }:
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 2;
        no_fade_out = true;
      };

      input-field = {
        monitor = "";
        size = "300, 50";
        outline_thickness = 0;
        fade_on_empty = false;
        placeholder_text = ''Password:'';
        dots_spacing = 0.3;
        dots_center = true;
        position = "0, -440";
      };

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
