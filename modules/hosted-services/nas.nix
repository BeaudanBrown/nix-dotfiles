{
  lib,
  config,
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

  corednsConfig =
    [ blocklistConfig ]
    ++ (
      tailServices
      |> map (s: ''
        ${s.domain}:53 {
          bind ${tailIP}
          hosts {
            ${if s.dnsTarget != null then s.dnsTarget else tailIP} ${s.domain}
            ttl 60
          }
          log
          errors
        }
      '')
    )
    |> concatStringsSep "\n\n";

  headscaleSplit = tailServices |> map (s: nameValuePair s.domain [ tailIP ]) |> listToAttrs;
in
{
  config = {
    services.headscale.settings.dns = {
      nameservers.split = headscaleSplit;
    };

    services.coredns = {
      enable = true;
      config = corednsConfig;
    };

    systemd.services.coredns = {
      requires = [
        "wait-for-tailscale-ip.service"
        "tailscaled.service"
      ];
      after = [
        "wait-for-tailscale-ip.service"
        "tailscaled.service"
        "headscale.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "5m";
      };
    };

    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 53 ];
  };
}
