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
    filter
    ;

  services = config.hostedServices;

  nginxVhosts =
    services
    |> filter (s: s.doNginx)
    |> map (
      s:
      nameValuePair s.domain {
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
    )
    |> listToAttrs;

  acmeCerts =
    services
    |> filter (s: s.doACME)
    |> map (
      s:
      nameValuePair s.domain {
        dnsProvider = "cloudflare";
        reloadServices = [ "nginx" ];
        environmentFile = config.sops.secrets."cloudflare/env".path;
      }
    )
    |> listToAttrs;

  cloudflareDomains = services |> map (s: s.domain);
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
              doACME = mkOption {
                type = types.bool;
                default = true;
                description = "If false, don't create an ACME certificate entry for this domain.";
              };
              dnsTarget = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "IP address to point DNS to. Defaults to host's tailIP.";
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

    sops.secrets."cloudflare/ddns_token" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      mode = "0600";
      owner = config.hostSpec.username;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };

    services.cloudflare-dyndns = {
      enable = true;
      proxied = false; # Disabled to allow UDP traffic (required for Headscale DERP/STUN)
      apiTokenFile = config.sops.secrets."cloudflare/ddns_token".path;
      domains = cloudflareDomains;
    };

    sops.secrets."cloudflare/env" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
    };

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
