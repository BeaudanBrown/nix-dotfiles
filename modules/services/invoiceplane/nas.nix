{ config, ... }:
let
  domain = "invoiceplane.bepis.lol";
  siteName = "default";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamPort = "80";
    }
  ];

  services.invoiceplane = {
    sites.${siteName} = {
      enable = true;
      database = {
        createLocally = true;
        name = "invoiceplane";
        user = "invoiceplane";
        passwordFile = config.sops.secrets."invoiceplane/database-password".path;
      };
      settings = {
        IP_URL = "https://${domain}";
        DISABLE_SETUP = true;
        SETUP_COMPLETED = true;
      };
      stateDir = "/pool1/appdata/invoiceplane";
    };
    webserver = "nginx";
  };

  users.users.${config.hostSpec.username}.extraGroups = [ "invoiceplane" ];

  sops.secrets."invoiceplane/database-password" = {
    mode = "0600";
    owner = "invoiceplane";
    group = "invoiceplane";
  };
}
