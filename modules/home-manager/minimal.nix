{ config, lib, ... }:
{
  # All users inherit the system's stateVersion.
  hm.all.home.stateVersion = lib.mkDefault (config.system.stateVersion or "23.05");

  # Keep legacy Home Manager defaults explicit for pre-26.05 profiles.
  # This silences state-version migration warnings without changing behavior.
  hmModules.all = lib.optionals (lib.versionOlder (config.system.stateVersion or "23.05") "26.05") [
    (
      { lib, ... }:
      {
        programs.yazi.shellWrapperName = lib.mkDefault "yy";
        wayland.windowManager.hyprland.configType = lib.mkDefault "hyprlang";
        xdg.userDirs.setSessionVariables = lib.mkDefault true;
      }
    )
  ];
}
