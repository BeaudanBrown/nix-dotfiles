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
in
{
  imports = [ inputs.ihp-roster.nixosModules.default ];

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

  sops.secrets."rozzy/bootstrap-password" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [ "bootstrap-account.service" ];
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
      email = "beaudan.brown@gmail.com";
      passwordFile = config.sops.secrets."rozzy/bootstrap-password".path;
      venueName = "Rozzy";
    };

    # Let IHP generate /var/ihp/session.aes on first boot until this is wired through sops-nix.
    sessionSecret = "";
  };
}
