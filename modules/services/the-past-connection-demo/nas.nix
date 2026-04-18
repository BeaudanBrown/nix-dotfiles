{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkDefault
    types
    getExe
    optional
    ;

  cfg = config.services.thePastConnectionDemo;
  sourcePathDefault = inputs.connection.outPath;
  userGroup = config.users.users.${cfg.user}.group;
  checkoutDir = "${cfg.stateDir}/checkout";
  frontendBuildDir = "${cfg.stateDir}/build";
  backupDir = "${cfg.stateDir}/backups";

  bootstrapScript = pkgs.writeShellApplication {
    name = "the-past-connection-demo-bootstrap";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
      pkgs.rsync
    ];
    text = ''
      set -euo pipefail

      if [ ! -d ${lib.escapeShellArg cfg.sourcePath} ]; then
        echo "Source path not found: ${cfg.sourcePath}" >&2
        exit 1
      fi

      rm -rf ${lib.escapeShellArg checkoutDir}
      mkdir -p ${lib.escapeShellArg checkoutDir}
      rsync -a --delete --chmod=Du+w,Fu+w ${lib.escapeShellArg "${cfg.sourcePath}/"} ${lib.escapeShellArg "${checkoutDir}/"}

      exec ${getExe config.nix.package} --extra-experimental-features "nix-command flakes" \
        run ${lib.escapeShellArg checkoutDir}#demo-bootstrap -- \
        --repo-root ${lib.escapeShellArg checkoutDir} \
        --public-supabase-url ${lib.escapeShellArg "https://${cfg.supabaseDomain}"} \
        --seed-mode once \
        --seed-marker ${lib.escapeShellArg "${cfg.stateDir}/demo-seeded"} \
        --output-dir ${lib.escapeShellArg frontendBuildDir}
    '';
  };

  serveScript = pkgs.writeShellApplication {
    name = "the-past-connection-demo-serve";
    runtimeInputs = [ config.nix.package ];
    text = ''
      set -euo pipefail

      exec ${getExe config.nix.package} --extra-experimental-features "nix-command flakes" \
        run ${lib.escapeShellArg checkoutDir}#demo-serve -- \
        --root ${lib.escapeShellArg "${frontendBuildDir}/dist"} \
        --port ${lib.escapeShellArg (toString cfg.frontendPort)}
    '';
  };

  backupScript = pkgs.writeShellApplication {
    name = "the-past-connection-demo-backup";
    runtimeInputs = [
      config.nix.package
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      set -euo pipefail

      if [ ! -d ${lib.escapeShellArg checkoutDir} ]; then
        echo "Demo checkout not found: ${checkoutDir}" >&2
        exit 1
      fi

      mkdir -p ${lib.escapeShellArg backupDir}
      timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
      schema_dump=${lib.escapeShellArg backupDir}/"supabase-$timestamp.schema.sql"
      data_dump=${lib.escapeShellArg backupDir}/"supabase-$timestamp.data.sql"

      cd ${lib.escapeShellArg checkoutDir}
      ${getExe config.nix.package} --extra-experimental-features "nix-command flakes" \
        develop .#default -c bash -lc \
        'supabase db dump --local --file "$1" && supabase db dump --local --data-only --use-copy --file "$2"' \
        bash "$schema_dump" "$data_dump"

      find ${lib.escapeShellArg backupDir} -type f -name 'supabase-*.sql' -mtime +${toString cfg.backupRetentionDays} -delete
      echo "Wrote $schema_dump and $data_dump"
    '';
  };
in
{
  options.services.thePastConnectionDemo = {
    enable = mkEnableOption "The Past Connection self-contained hosted demo";

    sourcePath = mkOption {
      type = types.str;
      default = sourcePathDefault;
      description = "Read-only source tree used to refresh the demo checkout before bootstrapping.";
    };

    domain = mkOption {
      type = types.str;
      default = "tpc-demo.bepis.lol";
      description = "Public domain for the frontend demo.";
    };

    supabaseDomain = mkOption {
      type = types.str;
      default = "tpc-demo-db.bepis.lol";
      description = "Public domain that proxies the local Supabase gateway.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/the-past-connection-demo";
      description = "Writable state directory for demo build artifacts and caches.";
    };

    user = mkOption {
      type = types.str;
      default = config.hostSpec.username;
      description = "User account that runs the demo bootstrap and static server.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional environment file for demo-specific settings such as admin seed credentials.";
    };

    backupRetentionDays = mkOption {
      type = types.ints.positive;
      default = 14;
      description = "Number of days to retain local Supabase dump files for the hosted demo.";
    };

    backupOnCalendar = mkOption {
      type = types.str;
      default = "daily";
      description = "systemd calendar expression for hosted demo Supabase backups.";
    };

    frontendPort = mkOption {
      type = types.port;
      default = 17284;
      description = "Localhost port used by the static frontend server.";
    };
  };

  config = mkMerge [
    {
      services.thePastConnectionDemo.enable = mkDefault true;
    }
    (mkIf cfg.enable {
      custom.ports.reserved = [ cfg.frontendPort ];

      hostedServices = [
        {
          domain = cfg.domain;
          upstreamHost = "127.0.0.1";
          upstreamPort = toString cfg.frontendPort;
        }
        {
          domain = cfg.supabaseDomain;
          upstreamHost = "127.0.0.1";
          upstreamPort = "54321";
          webSockets = true;
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0750 ${cfg.user} ${userGroup} - -"
        "d ${checkoutDir} 0750 ${cfg.user} ${userGroup} - -"
        "d ${frontendBuildDir} 0750 ${cfg.user} ${userGroup} - -"
        "d ${backupDir} 0750 ${cfg.user} ${userGroup} - -"
        "d ${cfg.stateDir}/npm-cache 0750 ${cfg.user} ${userGroup} - -"
        "d ${cfg.stateDir}/.local 0750 ${cfg.user} ${userGroup} - -"
        "d ${cfg.stateDir}/.cache 0750 ${cfg.user} ${userGroup} - -"
      ];

      systemd.services.the-past-connection-demo-bootstrap = {
        description = "Bootstrap The Past Connection hosted demo";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "docker.service"
        ];
        wants = [
          "network-online.target"
          "docker.service"
        ];
        serviceConfig = {
          PermissionsStartOnly = true;
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = userGroup;
          WorkingDirectory = cfg.stateDir;
          Environment = [
            "HOME=${cfg.stateDir}"
            "npm_config_cache=${cfg.stateDir}/npm-cache"
            "XDG_CACHE_HOME=${cfg.stateDir}/.cache"
            "XDG_STATE_HOME=${cfg.stateDir}/.local/state"
            "XDG_DATA_HOME=${cfg.stateDir}/.local/share"
          ];
          EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;
          ExecStartPre = [
            "${pkgs.coreutils}/bin/rm -rf ${checkoutDir}"
            "${pkgs.coreutils}/bin/mkdir -p ${checkoutDir}"
            "${pkgs.coreutils}/bin/chown ${cfg.user}:${userGroup} ${checkoutDir}"
          ];
          ExecStart = getExe bootstrapScript;
          TimeoutStartSec = "30min";
        };
      };

      systemd.services.the-past-connection-demo-web = {
        description = "Serve The Past Connection hosted demo";
        wantedBy = [ "multi-user.target" ];
        after = [ "the-past-connection-demo-bootstrap.service" ];
        requires = [ "the-past-connection-demo-bootstrap.service" ];
        serviceConfig = {
          User = cfg.user;
          Group = userGroup;
          WorkingDirectory = checkoutDir;
          Environment = [
            "HOME=${cfg.stateDir}"
            "XDG_CACHE_HOME=${cfg.stateDir}/.cache"
            "XDG_STATE_HOME=${cfg.stateDir}/.local/state"
            "XDG_DATA_HOME=${cfg.stateDir}/.local/share"
          ];
          ExecStart = getExe serveScript;
          Restart = "on-failure";
          RestartSec = "10s";
        };
      };

      systemd.services.the-past-connection-demo-backup = {
        description = "Back up The Past Connection hosted demo Supabase database";
        after = [
          "the-past-connection-demo-bootstrap.service"
          "docker.service"
        ];
        requires = [
          "the-past-connection-demo-bootstrap.service"
          "docker.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = userGroup;
          WorkingDirectory = cfg.stateDir;
          Environment = [
            "HOME=${cfg.stateDir}"
            "XDG_CACHE_HOME=${cfg.stateDir}/.cache"
            "XDG_STATE_HOME=${cfg.stateDir}/.local/state"
            "XDG_DATA_HOME=${cfg.stateDir}/.local/share"
          ];
          ExecStart = getExe backupScript;
          TimeoutStartSec = "30min";
        };
      };

      systemd.timers.the-past-connection-demo-backup = {
        description = "Run The Past Connection hosted demo Supabase backup";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.backupOnCalendar;
          Persistent = true;
        };
      };
    })
  ];
}
