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
    address = "0.0.0.0";
    port = 10101;
    settings = {
      server_url = "https://hs.bepis.lol:";
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
      oidc = {
        only_start_if_oidc_is_available = true;
        issuer = "https://auth.bepis.lol/application/o/headscale/";
        client_id = "VcSR0T2XYO8pfq8Akhhij2CGqQxXlvsRr0KyHeq9";
        client_secret_path = config.sops.secrets.headscale.path;
      };
    };
  };
  # Client secret key generated through authentik
  sops.secrets.headscale = {
    mode = "0600";
    owner = "headscale";
    group = "headscale";
  };
  sops.secrets.headscale_noise = {
    path = "/pool1/appdata/headscale/noise_private.key";
    mode = "0600";
    owner = "headscale";
    group = "headscale";
  };
}
