{ config, ... }:
{
  # fileSystems."/var/lib/litellm" = {
  #   device = "/pool1/appdata/litellm";
  #   options = [ "bind" ];
  # };
  # systemd.tmpfiles.rules = [
  #   "d /pool1/appdata/litellm/ 0700 vaultwarden vaultwarden - -"
  # ];
  services.nginx.virtualHosts."lan.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.headscale.port}";
    };
  };
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://lan.bepis.lol";
      dns.base_domain = "lan.bepis.lol";
    };
    port = 10101;
  };
}
