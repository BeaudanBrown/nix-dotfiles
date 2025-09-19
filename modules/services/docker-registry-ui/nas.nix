{ config, ... }:
let
  domain = "registry.bepis.lol";
  uiPortKey = "docker-registry-ui";
in
{
  custom.ports.requests = [ { key = uiPortKey; } ];

  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    containers."registry-ui" = {
      image = "docker.io/joxit/docker-registry-ui:2.5.7";
      autoStart = true;
      ports = [
        "127.0.0.1:${toString config.custom.ports.assigned.${uiPortKey}}:80"
      ];
      environment = {
        REGISTRY_URL = "https://${domain}";
        SINGLE_REGISTRY = "true";
        DELETE_IMAGES = "true";
        REGISTRY_SECURED = "true";
      };
    };
  };

  services.nginx.virtualHosts.${domain}.locations."/ui/" = {
    proxyPass = "http://127.0.0.1:${toString config.custom.ports.assigned.${uiPortKey}}/";
    extraConfig = ''
      auth_basic "Private Docker Registry UI";
      auth_basic_user_file ${config.sops.secrets."docker-registry/htpasswd".path};

      proxy_read_timeout 300s;
    '';
  };
}
