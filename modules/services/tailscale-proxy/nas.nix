{ config, lib, ... }:
let
  domain = "proxy.bepis.lol";
  headscaleDomain = "hs.bepis.lol";
  proxyPort = config.custom.ports.assigned."tailscale-proxy/tls";
  certificate = config.security.acme.certs.${domain};
in
{
  imports = [ ./runtime.nix ];

  custom.ports.requests = [ { key = "tailscale-proxy/tls"; } ];

  # Reuse the standard DNS-only Cloudflare DDNS and DNS-01 certificate path.
  # HTTP reverse proxying cannot carry Naive's HTTP/2 CONNECT transport.
  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString proxyPort;
      tlsPassthrough = true;
    }
  ];

  security.acme.certs.${domain} = {
    group = "sing-box";
    reloadServices = lib.mkForce [ "sing-box.service" ];
  };

  sops.secrets."tailscale-proxy/password" = {
    # Populate the matching key in secrets/nas.yaml; no plaintext default.
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "sing-box";
    group = "sing-box";
    mode = "0400";
    restartUnits = [ "sing-box.service" ];
  };

  services.sing-box.settings = {
    inbounds = [
      {
        type = "naive";
        tag = "authenticated-tailscale-proxy";
        listen = "127.0.0.1";
        listen_port = proxyPort;
        network = "tcp";
        users = [
          {
            username = "t480";
            password._secret = config.sops.secrets."tailscale-proxy/password".path;
          }
        ];
        tls = {
          enabled = true;
          certificate_path = "${certificate.directory}/fullchain.pem";
          key_path = "${certificate.directory}/key.pem";
        };
      }
    ];
    outbounds = [
      {
        type = "direct";
        tag = "internet";
      }
    ];
    route = {
      final = "internet";
      rules = [
        # This endpoint carries HTTPS control/DERP, not arbitrary LAN access.
        {
          network = "tcp";
          invert = true;
          action = "reject";
        }
        {
          port = 443;
          invert = true;
          action = "reject";
        }
        # Avoid WAN hairpin NAT for our own Headscale/embedded DERP. TLS
        # remains end-to-end with Headscale's nginx vhost via the TCP frontend.
        {
          domain = [ headscaleDomain ];
          action = "route";
          outbound = "internet";
          override_address = "127.0.0.1";
          override_port = 443;
        }
        { action = "resolve"; }
        {
          ip_is_private = true;
          action = "reject";
        }
      ];
    };
  };

  systemd.services.sing-box = {
    # The pinned ACME module prepares baseline files in acme-*.service and
    # obtains/renews trusted certificates in acme-order-renew-*.service.
    requires = [ "acme-${domain}.service" ];
    after = [ "acme-${domain}.service" ];
  };

  # The hostedServices registration owns ingress. NAS's own tailscaled must
  # NOT use this proxy, and its loopback backend needs no firewall opening.
}
