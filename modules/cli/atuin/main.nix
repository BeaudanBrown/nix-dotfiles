{ config, lib, ... }:
let
  portKey = "atuin";
  nasTailIP = config.hostSpecs.nas.tailIP;
  atuinKeyPath = "${config.hostSpec.home}/.local/share/atuin/key";
  atuinSessionPath = "${config.hostSpec.home}/.local/share/atuin/session";
in
{
  sops.secrets."atuin/key" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    path = atuinKeyPath;
    mode = "0600";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };

  sops.secrets."atuin/session" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    path = atuinSessionPath;
    mode = "0600";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };

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
        key_path = atuinKeyPath;
        session_path = atuinSessionPath;
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
