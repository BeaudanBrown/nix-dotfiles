{ lib, config, ... }:
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
    |> map (
      s:
      nameValuePair s.domain (
        {
          forceSSL = true;
          useACMEHost = s.domain;
          locations."/" = {
            proxyPass = "http://${s.upstreamHost}:${s.upstreamPort}";
            proxyWebsockets = s.webSockets;
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
