{ pkgs, config, ... }: {
  imports = [
    ./binds.nix
  ];

  xdg.portal = {
    enable = true;
    config = {
      common.default = [ "hyprland" ];
      hyprland.default = [ "gtk" "hyprland" ];
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {
      env = [
        "NIXOS_OZONE_WL, 1" # for ozone-based and electron apps to run on wayland
        "MOZ_ENABLE_WAYLAND, 1" # for firefox to run on wayland
        "MOZ_WEBRENDER, 1" # for firefox to run on wayland
        "XDG_SESSION_TYPE,wayland"
        "WLR_NO_HARDWARE_CURSORS,1"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
      ];

      general = {
        no_focus_fallback = true;
        gaps_out = 5;
      };

      cursor = {
        inactive_timeout = 2;
      };
      # TODO: Make this device specific
      # monitor = [
      #   "DP-1, 2560x1440@144, 2560x0, 1"
      #   "DP-2, 2560x1440@144, 0x0, 1"
      # ];
      monitor = [
        "eDP-1, 1920x1080@60, 0x0, 1"
      ];
      input = {
        accel_profile = "flat";
        sensitivity = -0.2;
        repeat_delay = 175;
        repeat_rate = 50;
        kb_options = "caps:escape,fn:escape";
        natural_scroll = true;
        follow_mouse = 2;
        touchpad = {
          natural_scroll = true;
          scroll_factor = 0.3;
          tap-and-drag = true;
        };
      };
      device = [
        {
          name = "2-synaptics-touchpad";
          sensitivity = 0.8;
        }
        {
          name = "syna3091:00-06cb:82f5-touchpad";
          sensitivity = 0.8;
        }
      ];

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };
      gestures = {
        workspace_swipe = true;
      };
      animations = {
        enabled = true;
        bezier = [
          "easein,0.1, 0, 0.5, 0"
          "easeinback,0.35, 0, 0.95, -0.3"

          "easeinquint,0.755, 0.05, 0.855, 0.06"
          "easeoutquint,0.23, 1, 0.32, 1"

          "easeout,0.5, 1, 0.9, 1"
          "easeoutback,0.35, 1.35, 0.65, 1"

          "easeinout,0.45, 0, 0.55, 1"
        ];

        animation = [
          "fadeIn,1,2.5,easeout"
          "windowsIn,1,2.5,easeoutback,slide"

          "fadeOut,1,2.5,easein"
          "windowsOut,1,2.5,easeinquint,slide"

          "windowsMove,1,5,easeoutquint"
          "workspaces,1,2.6,easeoutquint,slidefadevert"
        ];
      };
      binds = {
        allow_workspace_cycles = true;
        workspace_back_and_forth = true;
      };
      decoration = {
        inactive_opacity = 0.90;
        fullscreen_opacity = 1.0;
        rounding = 7;
      };
      windowrulev2 = import ./windowrulev2.nix;
    };
    extraConfig = ''
    exec-once = ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator &
    '';
  };
}
