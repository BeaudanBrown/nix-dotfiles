{ ... }:
let
  progress-bar = [
    "▏   "
    "▎   "
    "▍   "
    "▌   "
    "▋   "
    "▊   "
    "▉   "
    "█   "
    "█▏  "
    "█▎  "
    "█▍  "
    "█▌  "
    "█▋  "
    "█▊  "
    "█▉  "
    "██  "
    "██▏ "
    "██▎ "
    "██▍ "
    "██▌ "
    "██▋ "
    "██▊ "
    "██▉ "
    "███ "
    "███▏"
    "███▎"
    "███▍"
    "███▌"
    "███▋"
    "███▊"
    "███▉"
    "████"
  ];
in
{
  programs.waybar = {
    enable = true;
    style = ''
      .mainBar * {
        font-family: "JetBrainsMono Nerd Font Mono";
        font-size: 12pt;
      }

      .modules-right * {
        margin: 3;
      }
    '';
    settings = {
      mainBar = {
        name = "mainBar";
        layer = "top";
        position = "bottom";
        height = 30;
        modules-left = [
          "battery"
          "backlight"
          "wireplumber"
        ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [
          "tray"
          "memory"
          "clock"
        ];
        backlight = {
          device = "intel_backlight";
          format = "🔆 {icon} {percent:3}%";
          format-icons = progress-bar;
        };
        clock = {
          interval = 60;
          tooltip = true;
          format = "{:%I:%M%p}";
          tooltip-format = "{:%a %d/%m/%Y}";
        };
        memory = {
          interval = 10;
          format = "RAM: {used:0.1f}G/{total:0.1f}G";
        };
        wireplumber = {
          format = "🔊 {icon} {volume:3}%";
          format-muted = "🔇";
          # on-click = "helvum";
          on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          format-icons = progress-bar;
        };
        battery = {
          states = {
            # good = 95;
            warning = 30;
            critical = 15;
          };
          format = "🔋 {icon} {capacity:3}%";
          format-charging = "⚡ {icon} {capacity:3}%";
          format-plugged = "⚡ {icon} {capacity:3}%";
          format-icons = progress-bar;
        };
      };
    };
  };
}
