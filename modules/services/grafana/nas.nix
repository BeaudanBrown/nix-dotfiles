{
  config,
  lib,
  pkgs,
  ...
}:
let
  dashboardDefinitions = import ./dashboards.nix;
  dashboardDirectory = pkgs.symlinkJoin {
    name = "bepis-grafana-dashboards";
    paths = map (
      dashboard: pkgs.writeTextDir "${dashboard.uid}.json" (builtins.toJSON dashboard)
    ) dashboardDefinitions;
  };
  grafanaDomain = "grafana.bepis.lol";
  grafanaPort = 3301;
  productionTailIP = "100.64.0.16";
  tempoPort = 3200;
  lokiPort = 3101;
  developmentTempoTunnelPort = 20082;
  tempoEndpoint = "http://${productionTailIP}:${toString tempoPort}";
  lokiEndpoint = "http://${productionTailIP}:${toString lokiPort}";
  developmentTempoEndpoint = "http://127.0.0.1:${toString developmentTempoTunnelPort}";
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
          "127.0.0.1:${toString developmentTempoTunnelPort}"
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
              tracesToLogsV2 = {
                datasourceUid = "bepis-production-loki";
                spanStartTimeShift = "-30s";
                spanEndTimeShift = "30s";
                tags = [
                  {
                    key = "service.name";
                    value = "service_name";
                  }
                ];
                filterByTraceID = false;
                filterBySpanID = false;
              };
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
          {
            name = "Bepis Development Tempo";
            uid = "bepis-development-tempo";
            type = "tempo";
            access = "proxy";
            url = developmentTempoEndpoint;
            editable = false;
            jsonData = {
              httpMethod = "GET";
              nodeGraph.enabled = true;
            };
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "Bepis";
            orgId = 1;
            folder = "Bepis";
            folderUid = "bepis";
            type = "file";
            disableDeletion = false;
            allowUiUpdates = false;
            updateIntervalSeconds = 60;
            options = {
              path = dashboardDirectory;
              foldersFromFilesStructure = false;
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
