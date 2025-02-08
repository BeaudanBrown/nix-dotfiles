{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.suites.core;
in
{
  options.${namespace}.suites.core = with types; {
    enable = mkBoolOpt false "Whether or not to enable core configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [];

    # TODO: does this go somewhere else?
    console.useXkbConfig = true;

    dotfiles = {
      apps = {
        kitty = enabled;
        ledger_live = enabled;
        brave = enabled;
        obsidian = enabled;
        misc = enabled;
        teams = enabled;
      };
      cli = {
        git = enabled;
        sops = enabled;
        zsh = enabled;
        nixvim = enabled;
        misc = enabled;
      };
      desktop = {
        hyprland = enabled;
      };
      hardware = {
        networking = enabled;
        audio = enabled;
      };
      nix = enabled;
      security = {
        sudo = enabled;
        polkit = enabled;
      };
      services = {
        blueman = enabled;
        docker = enabled;
        printing = enabled;
        samba = enabled;
        ssh = enabled;
        syncthing = enabled;
        udisks2 = enabled;
        virtualbox = enabled;
      };
      system = {
        boot = enabled;
        fonts = enabled;
        locale = enabled;
        stylix = enabled;
        swap = enabled;
      };
      tools = {
        adb = enabled;
        autofs = enabled;
      };
    };
  };
}
