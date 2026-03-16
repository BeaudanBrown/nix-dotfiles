{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    types
    ;

  cfg = config.services.beads-dolt;
  serviceUser = cfg.user;
  serviceGroup = cfg.group;

  doltConfig = pkgs.writeText "beads-dolt-config.yaml" ''
    log_level: info
    log_format: text
    behavior:
      read_only: false
      autocommit: true
      event_scheduler: "OFF"
    listener:
      host: ${cfg.host}
      port: ${toString cfg.port}
    data_dir: ${cfg.dataDir}
    cfg_dir: ${cfg.dataDir}/.doltcfg
    privilege_file: ${cfg.dataDir}/.doltcfg/privileges.db
  '';

  startScript = pkgs.writeShellScript "beads-dolt-start" ''
    set -euo pipefail
    export DOLT_ROOT_HOST='%'
    export DOLT_ROOT_PASSWORD="$(cat ${config.sops.secrets."beads/dolt-root-password".path})"
    exec ${pkgs.dolt}/bin/dolt sql-server --config ${doltConfig}
  '';

  importScript = pkgs.writeShellScriptBin "beads-dolt-import-db" ''
    set -euo pipefail

    if [ "$#" -ne 2 ]; then
      echo "usage: beads-dolt-import-db <source-data-dir> <database-name>" >&2
      exit 1
    fi

    source_dir="$1"
    database_name="$2"
    source_db="$source_dir/$database_name"
    target_db="${cfg.dataDir}/$database_name"

    if [ ! -d "$source_db" ]; then
      echo "database '$database_name' not found under '$source_dir'" >&2
      exit 1
    fi

    if systemctl is-active --quiet beads-dolt.service; then
      echo "stop beads-dolt.service before importing data" >&2
      exit 1
    fi

    mkdir -p "${cfg.dataDir}"
    rm -rf "$target_db"
    cp -a "$source_db" "$target_db"
    chown -R ${serviceUser}:${serviceGroup} "$target_db"

    echo "imported '$database_name' into ${cfg.dataDir}"
    echo "start the service with: systemctl start beads-dolt.service"
  '';
in
{
  options.services.beads-dolt = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether nas should run the central Dolt SQL server for Beads.";
    };

    host = mkOption {
      type = types.str;
      default = config.hostSpec.tailIP;
      description = "Listener address for the central Dolt SQL server.";
    };

    port = mkOption {
      type = types.port;
      default = config.custom.beads.server.port;
      description = "TCP port for the central Dolt SQL server.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/beads-dolt";
      description = "Persistent Dolt data directory for Beads, outside synced project trees.";
    };

    user = mkOption {
      type = types.str;
      default = config.hostSpec.username;
      description = "User account that owns the Beads Dolt data directory and service.";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Primary group for the Beads Dolt service account.";
    };

    domain = mkOption {
      type = types.str;
      default = config.custom.beads.server.host;
      description = "Tailnet-only DNS name published for the central Beads Dolt service.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host != "";
        message = "services.beads-dolt.host must resolve to a concrete tailnet listener address.";
      }
    ];

    hostedServices = [
      {
        domain = cfg.domain;
        upstreamHost = cfg.host;
        upstreamPort = toString cfg.port;
        tailnet = true;
        doNginx = false;
        doACME = false;
        dnsTarget = cfg.host;
      }
    ];

    environment.systemPackages = [
      importScript
      pkgs.dolt
    ];

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    sops.secrets."beads/dolt-root-password" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 ${serviceUser} ${serviceGroup} - -"
      "d ${cfg.dataDir}/.doltcfg 0700 ${serviceUser} ${serviceGroup} - -"
    ];

    systemd.services.beads-dolt = {
      description = "Central Dolt SQL server for Beads";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "wait-for-tailscale-ip.service"
        "tailscaled.service"
      ];
      requires = [
        "wait-for-tailscale-ip.service"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = serviceUser;
        Group = serviceGroup;
        WorkingDirectory = cfg.dataDir;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "2m";
        UMask = "0077";
      };
    };
  };
}
