{ config, ... }:
{
  services.nginx.virtualHosts."hs.bepis.lol" = {
    forceSSL = true;
    enableACME = true;
    locations = {
      "/" = {
        proxyPass = "http://localhost:${toString config.services.headscale.port}";
        proxyWebsockets = true;
      };
      # "/metrics" = {
      #   proxyPass = "http://${config.services.headscale.settings.metrics_listen_addr}/metrics";
      # };
    };
  };
  services.headscale = {
    enable = true;
    port = 10101;
    settings = {
      server_url = "https://hs.bepis.lol";
      dns = {
        override_local_dns = true;
        base_domain = "lan";
        magic_dns = true;
        nameservers.global = [
          "1.1.1.1"
          "1.0.0.1"
          "2606:4700:4700::1111"
          "2606:4700:4700::1001"
        ];
      };
      tls_cert_path = null;
      tls_key_path = null;
      derp = {
        enabled = true;
      };
      oidc = {
        only_start_if_oidc_is_available = true;
        issuer = "https://auth.bepis.lol/application/o/headscale/";
        client_id = "FwfGvUzRKRPQWyFsV3PzKA0eh0T5qctUp8o0hpBL";
        client_secret_path = config.sops.secrets.headscale_authentic_secret.path;
      };
    };
  };
  # Client secret key generated through authentik
  sops.secrets.headscale_authentic_secret = {
    mode = "0600";
    owner = "headscale";
    group = "headscale";
  };
  sops.secrets.headscale_noise = {
    path = "/var/lib/headscale/noise_private.key";
    mode = "0600";
    owner = "headscale";
    group = "headscale";
  };
}
