{ config, ... }:
let
  portKey = "atuin";
  nasTailIP = config.hostSpecs.nas.tailIP;
in
{
  custom.ports = {
    requests = [
      {
        key = portKey;
      }
    ];
  };

  hm.primary = {
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      daemon.enable = true;
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "http://${nasTailIP}:${toString config.custom.ports.assigned.${portKey}}";
        search_mode = "fuzzy";
        filter_mode = "global";
      };
      forceOverwriteSettings = true;
    };

    # Keep zsh history local per host. Atuin handles cross-host history sync.
    programs.zsh.history = {
      path = "${config.hostSpec.home}/.local/state/zsh/history";
      append = true;
      share = false;
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreSpace = true;
    };
  };
}
