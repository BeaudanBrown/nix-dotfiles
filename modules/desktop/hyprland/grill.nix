{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Temporary: bypass GDM on grill while its greeter fails before login.
  services.displayManager.gdm.enable = lib.mkForce false;

  services.greetd = {
    enable = true;
    settings = {
      # Auto-start Hyprland for the primary user after boot.
      initial_session = {
        user = config.hostSpec.username;
        command = "Hyprland";
      };

      # Fallback TUI login if Hyprland exits.
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      };
    };
  };

  hm.primary.wayland.windowManager.hyprland.settings.monitor = [
    "DP-1, 2560x1440@144, 0x0, 1, vrr, 1"
    "DP-2, 2560x1440@144, 2560x0, 1, vrr, 1"
  ];
}
