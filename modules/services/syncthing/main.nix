{
  config,
  lib,
  ...
}:
{
  hm.primary.home.file."documents/.stignore".text = ''
    # Keep only stable repo-local Beads config synced. Runtime state, caches,
    # credentials, backups, and local version markers stay host-local.
    # Syncthing does not propagate .stignore itself, so Nix installs this on
    # each host.
    **/.beads/dolt
    **/.beads/dolt/**
    **/.beads/dolt-access.lock
    **/.beads/bd.sock
    **/.beads/bd.sock.startlock
    **/.beads/sync-state.json
    **/.beads/last-touched
    **/.beads/.exclusive-lock
    **/.beads/daemon.*
    **/.beads/interactions.jsonl
    **/.beads/push-state.json
    **/.beads/*.lock
    **/.beads/.beads-credential-key
    **/.beads/.local_version
    **/.beads/redirect
    **/.beads/.sync.lock
    **/.beads/export-state
    **/.beads/export-state/**
    **/.beads/ephemeral.sqlite3
    **/.beads/ephemeral.sqlite3-journal
    **/.beads/ephemeral.sqlite3-wal
    **/.beads/ephemeral.sqlite3-shm
    **/.beads/dolt-server.pid
    **/.beads/dolt-server.log
    **/.beads/dolt-server.lock
    **/.beads/dolt-server.port
    **/.beads/*.corrupt.backup
    **/.beads/*.corrupt.backup/**
    **/.beads/backup
    **/.beads/backup/**
    **/.beads/.env
    **/.beads/*.db
    **/.beads/*.db?*
    **/.beads/*.db-journal
    **/.beads/*.db-wal
    **/.beads/*.db-shm
    **/.beads/db.sqlite
    **/.beads/bd.db
  '';

  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.config/syncthing 0700 ${config.hostSpec.username} users - -"
    "d ${config.hostSpec.home}/.local/state/syncthing 0700 ${config.hostSpec.username} users - -"
  ];
  users.users.${config.hostSpec.username}.extraGroups = [ "syncthing" ];
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = config.hostSpec.username;
    dataDir = "${config.hostSpec.home}";
    settings = {
      options = {
        urAccepted = -1;
      };
      devices = {
        "server" = {
          id = "YZLDZHW-7MYKYEM-5PTTWLU-TBPEQJX-CJEFVBS-UYIOQJM-OKCQ723-25HTDAT";
          autoAcceptFolder = true;
        };
        "laptop" = {
          id = "T2YY6AY-XQNZQQW-RRI52RN-EARJZHR-6GPNA2A-2QBRMFD-TOHY5SH-MXFKVAC";
          autoAcceptFolder = true;
        };
        "grill" = {
          id = "B4SXNGB-I6QC6RM-GCPSPXR-JSCTBNJ-RTFDNVW-OPVO3TB-BQ7EDSO-ODJV4AC";
          autoAcceptFolder = true;
        };
        "lachy-thinkpad" = {
          id = "EJCNETP-BUV3ZI5-ADHABNE-OV3GPSW-LBTQ44J-73JW5G6-AUBM2CG-5E3YHA6";
          autoAcceptFolder = true;
        };
        "t480" = {
          id = "IP2ETPK-WVIYMUH-E4C4SF3-N55FC24-BBT4NFH-UYFD3LD-PPLVU3E-PL23UAM";
          autoAcceptFolder = true;
        };
      };
      folders = {
        "documents" = {
          id = "txxit-w9cwz";
          path = "${config.hostSpec.home}/documents";
          devices = [
            "server"
            "grill"
            "laptop"
            "t480"
          ];
        };
        "monash" = {
          id = "twjfr-ekoqc";
          path = "${config.hostSpec.home}/monash";
          devices = [
            "server"
            "grill"
            "laptop"
            "t480"
          ];
        };
        "collab" = {
          id = "vccfp-s5yfe";
          path = "${config.hostSpec.home}/collab";
          devices = [
            "server"
            "grill"
            "laptop"
            "t480"
            "lachy-thinkpad"
          ];
        };
        "state-sync" = {
          id = "state-sync";
          path = "${config.hostSpec.home}/.local/state/syncthing";
          devices = [
            "server"
            "grill"
            "laptop"
            "t480"
          ];
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      8384
    ];
  };
  sops.secrets."syncthing/${config.networking.hostName}/cert" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    path = "${config.hostSpec.home}/.config/syncthing/cert.pem";
    mode = "0400";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    restartUnits = [ "syncthing.service" ];
  };

  sops.secrets."syncthing/${config.networking.hostName}/key" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    path = "${config.hostSpec.home}/.config/syncthing/key.pem";
    mode = "0400";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    restartUnits = [ "syncthing.service" ];
  };
}
