{
  config,
  inputs,
  lib,
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

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  services.postgresql = {
    ensureUsers = [
      {
        name = databaseUser;
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [ databaseName ];
    authentication = lib.mkAfter ''
      local ${databaseName} ${databaseUser} trust
    '';
  };

  services.ihpRoster = {
    enable = true;
    inherit domain;
    baseUrl = "https://${domain}";
    appPort = config.custom.ports.assigned.${portKey};
    databaseName = databaseName;
    databaseUser = databaseUser;
    databaseUrl = "postgresql://${databaseUser}@/${databaseName}?host=/var/run/postgresql";
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
