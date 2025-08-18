{ lib, ... }:
{
  options.hypr.launchers = lib.mkOption {
    type =
      with lib.types;
      listOf (
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
        )
      );
    default = [ ];
    description = "Launcher entries that get converted to Hyprland binds.";
  };
}
