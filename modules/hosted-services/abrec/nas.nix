{ config, ... }:
let
  # Admin site: tailnet only and without a login, so being on the tailnet is
  # its only access control. Listener site and feeds: public, unlisted URLs.
  adminDomain = "abrec.bepis.lol";
  publicDomain = "audiobooks.bepis.lol";
  portKey = "abrec";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  # The agent-workshop module owns both virtual hosts; register their
  # certificates, DNS and listeners here.
  hostedServices = [
    {
      domain = adminDomain;
      tailnet = true;
      doNginx = false;
      manageNginxListeners = true;
    }
    {
      domain = publicDomain;
      doNginx = false;
      manageNginxListeners = true;
    }
  ];

  services.abrec = {
    enable = true;
    inherit adminDomain publicDomain;
    port = config.custom.ports.assigned.${portKey};
  };

  services.nginx.virtualHosts = {
    ${adminDomain} = {
      forceSSL = true;
      useACMEHost = adminDomain;
      # Generated tailnet vhosts get this from hostedServices; this one is
      # owned by the abrec module, so restrict it here.
      listenAddresses = [ config.hostSpec.tailIP ];
    };
    ${publicDomain} = {
      forceSSL = true;
      useACMEHost = publicDomain;
    };
  };
}
