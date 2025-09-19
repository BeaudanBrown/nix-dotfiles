{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    nameValuePair
    listToAttrs
    concatStringsSep
    filter
    ;

  services = config.hostedServices;
  tailIP = config.hostSpec.tailIP;

  publicServices = services |> filter (s: !s.tailnet);

  tailServices = services |> filter (s: s.tailnet);

  nginxVhosts =
    services
    |> filter (s: s.doNginx)
    |> map (
      s:
      nameValuePair s.domain (
        {
          forceSSL = true;
          useACMEHost = s.domain;
          # Allow larger uploads and long-running requests for proxied apps
          extraConfig = ''
            client_max_body_size 200m;
          '';
          locations."/" = {
            proxyPass = "http://${s.upstreamHost}:${s.upstreamPort}";
            proxyWebsockets = s.webSockets;
            extraConfig = ''
              proxy_request_buffering off;
              proxy_read_timeout 600s;
              proxy_send_timeout 600s;
            '';
          };
        }
        // (
          if s.tailnet then
            {
              listenAddresses = [ tailIP ];
            }
          else
            { }
        )
      )
    )
    |> listToAttrs;

  acmeCerts =
    services
    |> map (
      s:
      nameValuePair s.domain {
        dnsProvider = "cloudflare";
        reloadServices = [ "nginx" ];
        environmentFile = config.sops.secrets."cloudflare/env".path;
      }
    )
    |> listToAttrs;

  cloudflareDomains = publicServices |> map (s: s.domain);

  corednsConfig =
    tailServices
    |> map (s: ''
      ${s.domain}:53 {
        bind ${tailIP}
        hosts {
          ${tailIP} ${s.domain}
          ttl 60
        }
        log
        errors
      }
    '')
    |> concatStringsSep "\n\n";

  headscaleSplit = tailServices |> map (s: nameValuePair s.domain [ tailIP ]) |> listToAttrs;

  wait-for-tailscale-ip = pkgs.writeShellScript "wait-for-tailscale-ip" ''
    i=0
    until ip -4 addr show dev tailscale0 | grep -qw ${tailIP}; do
      sleep 1
      i=$((i+1))
      [ $i -ge 120 ] && break
    done

    if [ $i -ge 120 ]; then
      echo "Timed out waiting for tailscale IP ${tailIP}" >&2
      exit 1
    fi
  '';
in
{
  options = {
    hostedServices = mkOption {
      type = types.listOf (
        types.submodule (
          { ... }:
          {
            options = {
              domain = mkOption {
                type = types.str;
                description = "FQDN for this service (also used for ACME and DDNS).";
              };
              upstreamHost = mkOption {
                type = types.str;
                default = "127.0.0.1";
                description = "Upstream host for nginx proxy_pass.";
              };
              upstreamPort = mkOption {
                type = types.str;
                description = "Upstream port for nginx proxy_pass.";
              };
              tailnet = mkOption {
                type = types.bool;
                default = false;
                description = "If true, restrict nginx to tailIP and set Headscale/CoreDNS for this domain.";
              };
              webSockets = mkOption {
                type = types.bool;
                default = false;
                description = "If true, proxy websockets with nginx.";
              };
              doNginx = mkOption {
                type = types.bool;
                default = true;
                description = "If false, don't do nginx conf.";
              };
            };
          }
        )
      );
      default = [ ];
      description = "List of hosted services to configure.";
    };
  };

  config = {
    services.nginx.virtualHosts = nginxVhosts;

    services.headscale.settings.dns = {
      nameservers.split = headscaleSplit;
    };

    services.coredns = {
      enable = true;
      config = corednsConfig;
    };

    systemd.services.wait-for-tailscale-ip = {
      description = "Wait for Tailscale to have ${tailIP}";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [ wait-for-tailscale-ip ];
      };
      # Add required binaries to PATH for ExecStart
      path = [
        pkgs.iproute2
        pkgs.gnugrep
        pkgs.coreutils
      ];
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

    sops.secrets."cloudflare/ddns_token" = {
      mode = "0600";
      owner = config.hostSpec.username;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };

    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      53
      80
      443
    ];
    services.cloudflare-dyndns = {
      enable = true;
      proxied = true;
      apiTokenFile = config.sops.secrets."cloudflare/ddns_token".path;
      domains = cloudflareDomains;
    };

    sops.secrets."cloudflare/env" = { };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "beaudan.brown@gmail.com";
        group = "nginx";
      };
      certs = acmeCerts;
    };
  };
}
