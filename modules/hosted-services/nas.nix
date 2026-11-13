{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    nameValuePair
    listToAttrs
    concatStringsSep
    filter
    ;

  services = config.hostedServices;
  tailIP = config.hostSpec.tailIP;
  magicDnsDomain = config.services.headscale.settings.dns.base_domain;
  magicDnsResolver = "100.100.100.100";
  devTunnelPort = 20080;
  devTunnelToolPort = 20081;
  devTunnelTempoPort = 20082;
  tailServices = services |> filter (s: s.tailnet);

  blockedZones = [
    "facebook.com"
    "facebook.net"
    "fbcdn.net"
    "fbsbx.com"
    "messenger.com"
    "youtube.com"
    "youtu.be"
    "youtube-nocookie.com"
    "ytimg.com"
    "googlevideo.com"
  ];

  blockedZoneArgs = blockedZones |> concatStringsSep " ";
  hostedServiceHosts =
    tailServices
    |> map (s: "${if s.dnsTarget != null then s.dnsTarget else tailIP} ${s.domain}")
    |> concatStringsSep "\n";
  hostedRouteDomains = tailServices |> map (s: "~${s.domain}");

  blocklistConfig = ''
    .:53 {
      bind ${tailIP}

      template IN ANY ${blockedZoneArgs} {
        rcode NXDOMAIN
        authority "{{ .Zone }} 60 IN SOA ns.{{ .Zone }} hostmaster.{{ .Zone }} (1 60 60 60 60)"
      }

      forward . 1.1.1.1 9.9.9.9
      cache 300
      log
      errors
    }
  '';

  nasLocalResolverConfig = ''
    .:53 {
      bind 127.0.0.55

      hosts {
        ${hostedServiceHosts}
        fallthrough
      }

      forward . 1.1.1.1 9.9.9.9
      cache 300
      log
      errors
    }
  '';

  # NAS deliberately rejects the tailnet's complete DNS configuration so its
  # own lookups bypass blocked zones. Forward only MagicDNS to Tailscale.
  nasMagicDnsConfig = ''
    ${magicDnsDomain}:53 {
      bind 127.0.0.55
      forward . ${magicDnsResolver}
      cache 30
      log
      errors
    }
  '';

  # Keep local DNS alive independently of the tailnet listener. Exact hosted
  # zones are authoritative locally: unknown private names must not leak to
  # the public forwarders. Keep lan's search/forward behavior for short names.
  localCorednsConfig =
    [
      nasLocalResolverConfig
      nasMagicDnsConfig
    ]
    ++ (
      tailServices
      |> map (s: ''
        ${s.domain}:53 {
          bind 127.0.0.55
          hosts {
            ${hostedServiceHosts}
            ttl 60
          }
          log
          errors
        }
      '')
    )
    |> concatStringsSep "\n\n";

  tailnetCorednsConfig =
    [ blocklistConfig ]
    ++ (
      tailServices
      |> map (s: ''
        ${s.domain}:53 {
          bind ${tailIP}
          hosts {
            ${hostedServiceHosts}
            ttl 60
          }
          log
          errors
        }
      '')
    )
    |> concatStringsSep "\n\n";

  headscaleServiceSplit = tailServices |> map (s: nameValuePair s.domain [ tailIP ]) |> listToAttrs;
  headscaleBlocklistSplit = blockedZones |> map (zone: nameValuePair zone [ tailIP ]) |> listToAttrs;
  headscaleSplit = headscaleServiceSplit // headscaleBlocklistSplit;
in
{
  config = {
    # A stable public HTTPS slot for an operator-started SSH reverse tunnel.
    # The remote listener stays on NAS loopback; only nginx exposes the slot.
    custom.ports.reserved = [
      devTunnelPort
      devTunnelToolPort
      devTunnelTempoPort
    ];
    hostedServices = [
      {
        domain = "dev.bepis.lol";
        upstreamHost = "127.0.0.1";
        upstreamPort = toString devTunnelPort;
        tailnet = false;
        webSockets = true;
      }
    ];
    services.nginx.virtualHosts."dev.bepis.lol".locations."/__ihp-livereload" = {
      proxyPass = "http://127.0.0.1:${toString devTunnelToolPort}/";
      proxyWebsockets = true;
    };

    services.headscale.settings.dns = {
      nameservers.split = headscaleSplit;
    };

    services.coredns = {
      enable = true;
      config = localCorednsConfig;
    };

    services.resolved.settings.Resolve = {
      DNS = [ "127.0.0.55" ];
      # A non-route-only domain also supplies the short-name search suffix.
      Domains = hostedRouteDomains ++ [ magicDnsDomain ];
    };

    # No Headscale/Tailscale dependency on the loopback resolver. A missing
    # tailnet IP must never prevent local DNS or OIDC discovery from working.
    systemd.services.coredns.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
    };

    systemd.services.coredns-tailnet = {
      description = "Tailnet DNS and domain blocking";
      wantedBy = [ "multi-user.target" ];
      wants = [ "tailscaled.service" ];
      after = [ "tailscaled.service" ];
      # Retry our own readiness check, rather than failing a Requires job that
      # Restart=on-failure cannot recover when the IP arrives later.
      startLimitIntervalSec = 0;
      preStart = ''
        for attempt in $(${pkgs.coreutils}/bin/seq 1 120); do
          if ${pkgs.iproute2}/bin/ip -4 addr show dev tailscale0 | ${pkgs.gnugrep}/bin/grep -qw ${lib.escapeShellArg tailIP}; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "Tailnet DNS waiting for ${tailIP}; will retry" >&2
        exit 1
      '';
      serviceConfig = {
        ExecStart = "${config.services.coredns.package}/bin/coredns -conf=${pkgs.writeText "Corefile-tailnet" tailnetCorednsConfig}";
        DynamicUser = true;
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        NoNewPrivileges = true;
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "150s";
      };
    };

    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 53 ];
  };
}
