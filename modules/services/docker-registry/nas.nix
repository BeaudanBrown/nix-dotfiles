{ config, ... }:
let
  domain = "registry.bepis.lol";
  portKey = "docker-registry";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.dockerRegistry.listenAddress;
      upstreamPort = toString config.services.dockerRegistry.port;
      webSockets = false;
    }
  ];

  services.dockerRegistry = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    enableDelete = true;
    enableGarbageCollect = true;
    garbageCollectDates = "weekly";
    extraConfig = {
      http.headers = {
        "X-Content-Type-Options" = [ "nosniff" ];
      };
    };
  };

  services.nginx.virtualHosts.${domain} = {
    locations."/v2/" = {
      proxyPass = "http://127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
      extraConfig = ''
        # AuthN at nginx so the registry can stay simple
        auth_basic "Private Docker Registry";
        auth_basic_user_file ${config.sops.secrets."docker-registry/htpasswd".path};

        # Required for large uploads/pushes
        client_max_body_size 0;
        proxy_read_timeout 900s;
        proxy_request_buffering off;
      '';
    };
  };

  sops.secrets."docker-registry/htpasswd" = {
    # Keep it in /etc so it's available early and readable by nginx
    # path = "/etc/secrets/docker-registry/htpasswd";
    mode = "0640";
    owner = "nginx";
    group = "nginx";
  };
}
