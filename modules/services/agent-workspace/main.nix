{ config, lib, ... }:
{
  # Shared project data only. Harness state, credentials and live databases
  # belong outside this tree. Replication deliberately has no writer lock.
  users.groups.agent-workspace = { };
  users.groups.dsh-agent = { };
  users.users = {
    dsh-agent = {
      isSystemUser = true;
      group = "dsh-agent";
      extraGroups = [ "agent-workspace" ];
      home = "/var/lib/dsh-agent";
      createHome = false;
    };
  }
  //
    lib.genAttrs
      (lib.unique [
        config.hostSpec.username
        config.services.syncthing.user
      ])
      (_: {
        extraGroups = [ "agent-workspace" ];
      });

  # This workspace is intentionally shared with the agent and sync peers. Keep
  # the exception in the operator's protected Git config, not root's or other users'.
  # Git reads this alongside ~/.gitconfig, so existing personal entries still work.
  hm.primary.xdg.configFile."git/config".text = ''
    [safe]
      directory = /agent/*
  '';

  systemd.tmpfiles.rules = [
    "d /agent 2770 ${config.services.syncthing.user} agent-workspace - -"
    "a /agent - - - - u::rwx,g::rwx,m::rwx,o::---,d:u::rwx,d:g::rwx,d:m::rwx,d:o::---"
  ];

  # Group database changes alone need not restart an existing daemon. Put the
  # shared group in both units so activation refreshes their credentials.
  systemd.services.syncthing.serviceConfig.SupplementaryGroups = [ "agent-workspace" ];
  systemd.services.syncthing-init.serviceConfig.SupplementaryGroups = [ "agent-workspace" ];

  services.syncthing.settings.folders.agent-workspace = {
    id = "agent-workspace-v1";
    path = "/agent";
    type = "sendreceive";
    devices = [
      "server"
      "grill"
      "t480"
      "laptop"
    ];
    ignorePerms = true;
    # Deliberately NOT the existing documents folder's broad ignore policy:
    # Git, untracked files, conflict files, data and build outputs are retained.
    ignorePatterns = [
      "(?d)**/node_modules"
      "(?d)**/.venv"
      "(?d)**/__pycache__"
      "(?d)**/.pytest_cache"
      "(?d)**/.mypy_cache"
      "(?d)**/.ruff_cache"
    ];
  };

  assertions = [
    {
      assertion = config.services.syncthing.enable;
      message = "The main-root agent workspace requires the existing Syncthing service.";
    }
    {
      assertion =
        !(lib.elem "wheel" config.users.users.dsh-agent.extraGroups)
        && !(lib.elem "docker" config.users.users.dsh-agent.extraGroups);
      message = "The development agent must not inherit wheel or Docker authority.";
    }
  ];
}
