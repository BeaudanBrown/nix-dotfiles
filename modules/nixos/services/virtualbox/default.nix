{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.services.virtualbox;
in {
  options.${namespace}.services.virtualbox = {
    enable = mkBoolOpt false "Whether or not to enable virtualbox.";
  };

  config = mkIf cfg.enable
  (import ./scripts/launch_windows.nix { inherit pkgs; }) //
  {
    users.extraGroups.vboxusers.members = ["beau"];
    virtualisation = {
      virtualbox = {
        guest = {
          # Enabling this causes slow rebuild (potentially hanging while waiting for credentials?)
          enable = false;
          dragAndDrop = true;
        };
        host = {
          enable = true;
        };
      };
    };
  };
}
