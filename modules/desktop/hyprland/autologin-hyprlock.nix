{
  config,
  lib,
  pkgs,
  ...
}:
let
  hyprlandSessionCommand = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland ${config.programs.hyprland.package}/bin/start-hyprland";
in
{
  # Temporary: bypass GDM on work devices while its greeter fails before login.
  # Use the upstream-recommended UWSM startup path without replacing
  # XDG_DATA_DIRS, so the session keeps the normal NixOS icon/theme data dirs.
  # greetd starts the primary user's Hyprland session automatically, then
  # Hyprland immediately locks with hyprlock.
  services = {
    displayManager.gdm.enable = lib.mkForce false;
    greetd = {
      enable = true;
      settings = {
        initial_session = {
          user = config.hostSpec.username;
          command = hyprlandSessionCommand;
        };

        # greetd requires a default session even when initial_session is used.
        # Keep a minimal text fallback for logout/restart/debug paths; normal
        # boot still autologins via initial_session above.
        default_session = {
          user = "greeter";
          command = "${pkgs.greetd}/bin/agreety --cmd ${lib.escapeShellArg hyprlandSessionCommand}";
        };
      };
    };
  };

  hm.primary.wayland.windowManager.hyprland.settings.exec-once = lib.mkBefore [
    "${pkgs.hyprlock}/bin/hyprlock"
  ];
}
