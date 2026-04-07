{
  config,
  inputs,
  ...
}:
let
  domain = "rozzy.bepis.lol";
  portKey = "ihp-roster-demo";
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

  services.ihpRoster = {
    enable = true;
    inherit domain;
    baseUrl = "https://${domain}";
    appPort = config.custom.ports.assigned.${portKey};
    configureNginx = false;

    # Temporary demo-only secret until this is wired through sops-nix.
    # Replace with environmentFile-backed secrets before treating this as production.
    sessionSecret = "ihp-roster-demo-change-me";
  };
}
