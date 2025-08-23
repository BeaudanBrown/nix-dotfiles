{ config, ... }:
let
  domain = "hs.bepis.lol";
  portKey = "headscale";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  services.headscale = {
    enable = true;
    port = config.custom.ports.assigned.${portKey};
    settings = {
      server_url = "https://${domain}";
      dns = {
        base_domain = "lan";
        magic_dns = true;
        override_local_dns = false;
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
        client_secret_path = config.sops.secrets."headscale/authentik_secret".path;
      };
    };
  };
  # Client secret key generated through authentik
  sops.secrets."headscale/authentik_secret" = {
    mode = "0600";
    owner = "headscale";
    group = "headscale";
  };
  sops.secrets."headscale/noise" = {
    path = "/var/lib/headscale/noise_private.key";
    mode = "0600";
    owner = "headscale";
    group = "headscale";
  };
}
