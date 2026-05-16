{ lib, ... }:
let
  launcherType =
    with lib.types;
    submodule (
      { ... }:
      {
        options = {
          key = lib.mkOption { type = str; };
          app = lib.mkOption { type = str; };
          workspace = lib.mkOption { type = str; };
          class = lib.mkOption {
            type = nullOr str;
            default = null;
          };
          title = lib.mkOption {
            type = nullOr str;
            default = null;
          };
        };
      }
    );
in
{
  options.hypr = {
    launchers = lib.mkOption {
      type = with lib.types; listOf launcherType;
      default = [ ];
      description = "Launcher entries that get converted to Hyprland binds.";
    };

    windowsLauncher = lib.mkOption {
      type = launcherType;
      default = {
        key = "v";
        app = "launch_windows";
        workspace = "Windows";
        class = "VirtualBox Machine";
      };
      description = "Launcher entry for the Windows VM shortcut.";
    };
  };
}
