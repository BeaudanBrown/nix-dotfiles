{ config, lib, ... }:
let
  passthrough = config.hostedServices |> lib.filter (s: s.tlsPassthrough);
  websites = config.hostedServices |> lib.filter (s: s.manageNginxListeners);
  enabled = passthrough != [ ];
  ports = config.custom.ports.assigned;
  publicPort = ports."nginx-ingress/public";
  privatePort = ports."nginx-ingress/tailnet";
  passthroughPort = ports."nginx-ingress/passthrough";

  # Named upstreams let nginx resolve configured upstream hostnames at startup;
  # variable proxy_pass otherwise requires a separate runtime DNS resolver.
  upstreams = lib.imap0 (i: service: {
    name = "hosted_tls_${toString i}";
    inherit service;
  }) passthrough;
  upstreamConfig =
    upstreams
    |> map (upstream: ''
      upstream ${upstream.name} {
        server ${upstream.service.upstreamHost}:${upstream.service.upstreamPort};
      }
    '')
    |> lib.concatStringsSep "\n";
  hostnameMap =
    upstreams
    |> lib.concatMap (
      upstream:
      [ upstream.service.domain ] ++ upstream.service.serverAliases
      |> map (hostname: "${hostname} ${upstream.name};")
    )
    |> lib.concatStringsSep "\n";

  tlsListen = port: {
    addr = "127.0.0.1";
    inherit port;
    ssl = true;
    proxyProtocol = true;
  };
  listeners =
    tailnet:
    lib.optional (!tailnet) (tlsListen publicPort)
    ++ [ (tlsListen privatePort) ]
    ++ [
      {
        addr = if tailnet then config.hostSpec.tailIP else "0.0.0.0";
        port = 80;
      }
    ]
    ++ lib.optional (!tailnet && config.networking.enableIPv6) {
      addr = "[::]";
      port = 80;
    };
in
{
  # No registered passthrough service means no ports, frontend, or listener
  # overrides: existing websites (including externally owned ones) stay native.
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = lib.all (s: !s.tailnet && !s.doNginx && !s.manageNginxListeners) passthrough;
        message = "hostedServices TLS passthrough requires a public TLS upstream, doNginx = false and manageNginxListeners = false.";
      }
    ];

    custom.ports.requests = [
      { key = "nginx-ingress/public"; }
      { key = "nginx-ingress/tailnet"; }
      { key = "nginx-ingress/passthrough"; }
    ];

    services.nginx = {
      enable = true;
      streamConfig = ''
        ${upstreamConfig}

        # Destination address, not client-supplied SNI/Host, gates private sites.
        map $server_addr $hosted_https_backend {
          ${config.hostSpec.tailIP} 127.0.0.1:${toString privatePort};
          default 127.0.0.1:${toString publicPort};
        }

        map $ssl_preread_server_name $hosted_tls_upstream {
          hostnames;
          default "";
          ${hostnameMap}
        }

        map $hosted_tls_upstream $hosted_tls_backend {
          "" $hosted_https_backend;
          default 127.0.0.1:${toString passthroughPort};
        }

        server {
          listen 0.0.0.0:443;
          ${lib.optionalString config.networking.enableIPv6 "listen [::]:443 ipv6only=on;"}
          ssl_preread on;
          preread_timeout 10s;
          proxy_connect_timeout 10s;
          proxy_timeout 1h;
          proxy_protocol on;
          proxy_pass $hosted_tls_backend;
        }

        # Website backends consume PROXY headers to restore client IPs.
        # Raw TLS upstreams do not: strip the header on loopback and route
        # again by SNI, without decrypting or modifying the TLS stream.
        server {
          listen 127.0.0.1:${toString passthroughPort} proxy_protocol;
          ssl_preread on;
          preread_timeout 10s;
          proxy_connect_timeout 10s;
          proxy_timeout 1h;
          proxy_protocol off;
          proxy_pass $hosted_tls_upstream;
        }
      '';

      virtualHosts =
        websites
        |> map (
          s:
          lib.nameValuePair s.domain {
            # Public websites exist on both backends; private ones ONLY on the
            # tailnet backend. Port 80 keeps its original address restrictions.
            listen = lib.mkForce (listeners s.tailnet);
            extraConfig = ''
              set_real_ip_from 127.0.0.1;
              real_ip_header proxy_protocol;
            '';
          }
        )
        |> lib.listToAttrs;
    };
  };
}
