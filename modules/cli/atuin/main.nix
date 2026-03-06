{ config, ... }:
{
  hm.primary = {
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      daemon.enable = true;
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "http://100.64.0.4:8888";
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
