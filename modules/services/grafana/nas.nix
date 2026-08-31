{ config, lib, ... }:
let
  grafanaDomain = "grafana.bepis.lol";
  grafanaPort = 3301;
  productionTailIP = "100.64.0.16";
  tempoPort = 3200;
  lokiPort = 3101;
  tempoEndpoint = "http://${productionTailIP}:${toString tempoPort}";
  lokiEndpoint = "http://${productionTailIP}:${toString lokiPort}";
in
{
  hostedServices = [
    {
      domain = grafanaDomain;
      upstreamPort = toString grafanaPort;
      tailnet = true;
    }
  ];

  services.grafana = {
    enable = true;
    openFirewall = false;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = grafanaDomain;
        root_url = "https://${grafanaDomain}/";
        enforce_domain = true;
        enable_gzip = true;
      };

      security = {
        admin_password = "$__file{${config.sops.secrets."grafana/admin-password".path}}";
        secret_key = "$__file{${config.sops.secrets."grafana/secret-key".path}}";
        cookie_secure = true;
        cookie_samesite = "strict";
        disable_gravatar = true;
        strict_transport_security = true;
        data_source_proxy_whitelist = [
          "${productionTailIP}:${toString tempoPort}"
          "${productionTailIP}:${toString lokiPort}"
        ];
      };

      users = {
        allow_sign_up = false;
        allow_org_create = false;
      };

      "auth.anonymous".enabled = false;
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "Bepis Production Tempo";
            uid = "bepis-production-tempo";
            type = "tempo";
            access = "proxy";
            url = tempoEndpoint;
            editable = false;
            jsonData = {
              httpMethod = "GET";
              nodeGraph.enabled = true;
            };
          }
          {
            name = "Bepis Production Loki";
            uid = "bepis-production-loki";
            type = "loki";
            access = "proxy";
            url = lokiEndpoint;
            editable = false;
            jsonData = {
              httpMethod = "GET";
              maxLines = 200;
            };
          }
        ];
      };
    };
  };

  sops.secrets = {
    "grafana/admin-password" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      restartUnits = [ "grafana.service" ];
    };
    "grafana/secret-key" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      restartUnits = [ "grafana.service" ];
    };
  };

  systemd.services.grafana = {
    after = [ "tailscaled.service" ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
  };
}
