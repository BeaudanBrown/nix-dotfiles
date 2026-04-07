{
  config,
  inputs,
  lib,
  ...
}:
let
  domain = "rozzy.bepis.lol";
  portKey = "ihp-roster-demo";
  databaseName = "ihp_roster";
  databaseUser = "ihp_roster";
in
{
  imports = [ inputs.ihp-roster.nixosModules.default ];

  custom.ports.requests = [ { key = portKey; } ];

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

    # Let IHP generate /var/ihp/session.aes on first boot until this is wired through sops-nix.
    sessionSecret = "";
  };
}
