{ config, ... }:
let
  # Keep the UI on the same domain as the registry to avoid CORS
  domain = "registry.bepis.lol";
  uiPortKey = "docker-registry-ui";
in
{
  # Local loopback port for the UI container
  custom.ports.requests = [ { key = uiPortKey; } ];

  # Run Joxit docker-registry-ui as a container (podman/oci-containers)
  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    enable = true;
    containers."registry-ui" = {
      image = "docker.io/joxit/docker-registry-ui:2.5.7";
      autoStart = true;
      # Bind only to loopback
      ports = [
        "127.0.0.1:${toString config.custom.ports.assigned.${uiPortKey}}:80"
      ];
      environment = {
        SINGLE_REGISTRY = "true";
        DELETE_IMAGES = "true"; # you confirmed delete is fine
        REGISTRY_SECURED = "true"; # reduce extra auth-check calls
        # No NGINX_PROXY_PASS_URL needed since UI and registry share the same origin
      };
      # Keep container network isolated; no volumes required
    };
  };

  # Publish UI under /ui on the same vhost that serves the registry
  services.nginx.virtualHosts.${domain}.locations."/ui/" = {
    proxyPass = "http://127.0.0.1:${toString config.custom.ports.assigned.${uiPortKey}}/";
    extraConfig = ''
      # Reuse the same Basic Auth as the registry so browser credentials apply
      auth_basic "Private Docker Registry UI";
      auth_basic_user_file ${config.sops.secrets."docker-registry/htpasswd".path};

      proxy_read_timeout 300s;
    '';
  };
}
