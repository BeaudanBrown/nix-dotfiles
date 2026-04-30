{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  domain = "bepis.lol";
  portKey = "rozzy";
  databaseName = "rozzy";
  databaseUser = "rozzy";
  rosterPackage = inputs.ihp-roster.packages.${pkgs.system}.default;
  resetDatabaseScript = pkgs.writeShellApplication {
    name = "rozzy-reset-database";
    runtimeInputs = [
      config.services.postgresql.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      confirmation_flag="--danger"
      seed_dev=0
      seed_args=()

      if [ "''${1:-}" != "$confirmation_flag" ]; then
        echo "Usage: rozzy-reset-database $confirmation_flag [--seed-dev [seed-options...]]" >&2
        echo "This destroys and recreates the local Rozzy database, then loads the schema and bootstrap account." >&2
        echo "With --seed-dev, it then replaces the bootstrap data with dummy development fixture data." >&2
        exit 64
      fi
      shift

      if [ "''${1:-}" = "--seed-dev" ]; then
        seed_dev=1
        shift
        seed_args=("$@")
      elif [ "$#" -gt 0 ]; then
        echo "Unsupported reset option: $1" >&2
        echo "Usage: rozzy-reset-database $confirmation_flag [--seed-dev [seed-options...]]" >&2
        exit 64
      fi

      if [ "$(id -u)" -ne 0 ]; then
        echo "rozzy-reset-database must be run as root." >&2
        exit 1
      fi

      database_name=${lib.escapeShellArg databaseName}
      database_user=${lib.escapeShellArg databaseUser}
      database_url=${lib.escapeShellArg "postgresql://${databaseUser}@/${databaseName}?host=/var/run/postgresql"}
      app_base_url=${lib.escapeShellArg "https://${domain}"}
      dev_reference_data=${lib.escapeShellArg "${inputs.ihp-roster}/Application/Support/Seed/DevReferenceData.sql"}
      postgres_db=postgres
      units=(
        app.socket
        app.service
        worker.service
        bootstrap-account.service
        migrate.service
        loadSchema.service
      )

      echo "[rozzy-reset] stopping Rozzy application units"
      systemctl stop "''${units[@]}" || true
      systemctl reset-failed "''${units[@]}" || true

      echo "[rozzy-reset] terminating database sessions"
      runuser -u postgres -- psql "$postgres_db" \
        --set=ON_ERROR_STOP=1 \
        --quiet \
        --command="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$database_name' AND pid <> pg_backend_pid();" \
        >/dev/null

      echo "[rozzy-reset] recreating database"
      runuser -u postgres -- dropdb --if-exists "$database_name"
      runuser -u postgres -- createdb --owner "$database_user" "$database_name"

      echo "[rozzy-reset] loading schema"
      systemctl start loadSchema.service

      echo "[rozzy-reset] running bootstrap account seed"
      systemctl start bootstrap-account.service

      if [ "$seed_dev" = "1" ]; then
        echo "[rozzy-reset] loading dev reference data"
        runuser -u "$database_user" -- psql "$database_url" \
          --set=ON_ERROR_STOP=1 \
          --file "$dev_reference_data"

        echo "[rozzy-reset] running development seed"
        runuser -u "$database_user" -- env \
          DATABASE_URL="$database_url" \
          IHP_TELEMETRY_DISABLED=1 \
          APP_BASE_URL="$app_base_url" \
          ${rosterPackage}/bin/SeedDev "''${seed_args[@]}"
      fi

      echo "[rozzy-reset] checking resulting database shape"
      runuser -u "$database_user" -- psql "$database_name" \
        --tuples-only \
        --no-align \
        --command="SELECT to_regclass('public.app_jobs') IS NOT NULL;" \
        | grep -qx t

      echo "[rozzy-reset] starting application units"
      systemctl start app.socket
      systemctl start app.service
      systemctl start worker.service

      echo "[rozzy-reset] complete"
      systemctl --no-pager --plain status app.socket app.service worker.service bootstrap-account.service loadSchema.service >/dev/null
    '';
  };
in
{
  imports = [ inputs.ihp-roster.nixosModules.default ];

  nix.settings = {
    substituters = [
      "https://digitallyinduced.cachix.org"
    ];
    trusted-public-keys = [
      "digitallyinduced.cachix.org-1:y+wQvrnxQ+PdEsCt91rmvv39qRCYzEgGQaldK26hCKE="
    ];
  };

  services.nginx = {
    enable = true;
    proxyTimeout = "240s";
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };

  custom.ports.requests = [ { key = portKey; } ];

  sops.secrets."rozzy/bootstrap-account" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [ "bootstrap-account.service" ];
    mode = "0400";
  };

  sops.secrets."rozzy/env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [
      "app.service"
      "worker.service"
    ];
  };

  sops.secrets."rozzy/restic-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
  };

  sops.secrets."rozzy/restic-password" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
  };

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  environment.systemPackages = [ resetDatabaseScript ];

  services.postgresql = {
    enable = true;
    enableTCPIP = false;
    ensureUsers = [
      {
        name = databaseUser;
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [ databaseName ];
    authentication = lib.mkForce ''
      local all postgres peer
      local ${databaseName} ${databaseUser} peer
      local all all reject
    '';
  };

  services.restic.backups.rozzy-postgres = {
    initialize = true;
    repository = "s3:https://sg-sin-1.linodeobjects.com/rozzy-backups/rozzy-postgres";
    environmentFile = config.sops.secrets."rozzy/restic-env".path;
    passwordFile = config.sops.secrets."rozzy/restic-password".path;

    command = [
      "${pkgs.util-linux}/bin/runuser"
      "-u"
      databaseUser
      "--"
      "${config.services.postgresql.package}/bin/pg_dump"
      "--format=custom"
      "--no-owner"
      "--no-acl"
      databaseName
    ];

    extraBackupArgs = [
      "--stdin-filename"
      "rozzy.pgcustom"
      "--tag"
      "postgres"
      "--tag"
      "ihp-roster"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };

    pruneOpts = [
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 24"
      "--group-by tags"
    ];

    checkOpts = [ "--read-data-subset=1G" ];
  };

  services.ihpRoster = {
    enable = true;
    inherit domain;
    baseUrl = "https://${domain}";
    appPort = config.custom.ports.assigned.${portKey};
    databaseName = databaseName;
    databaseUser = databaseUser;
    databaseUrl = "postgresql://${databaseUser}@/${databaseName}?host=/var/run/postgresql";
    serviceUser = databaseUser;
    createServiceUser = true;
    managePostgres = false;
    enableMigrations = false;
    configureNginx = false;

    # Secret file placeholder for email delivery settings. Expected keys:
    # MAIL_FROM=...
    # SMTP_HOST=...
    # SMTP_PORT=...
    # SMTP_ENCRYPTION=...
    # SMTP_USER=...
    # SMTP_PASSWORD=...
    # RESEND_API_KEY=... (reserved for an eventual Resend transport switch)
    environmentFile = config.sops.secrets."rozzy/env".path;

    bootstrap = {
      enable = true;
      secretFile = config.sops.secrets."rozzy/bootstrap-account".path;
    };

    # Let IHP generate /var/ihp/session.aes on first boot until this is wired through sops-nix.
    sessionSecret = "";
  };
}
