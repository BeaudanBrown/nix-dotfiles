{ config, lib, ... }:
let
  domain = "moonlight.bepis.lol";
  portKey = "moonlight";
  dataRoot = "/var/lib/moonlight";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${dataRoot} 0755 root root - -"
    "d ${dataRoot}/data 0755 root root - -"
  ];

  sops.secrets."docker-registry/pass" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
  };

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.containers.moonlight = {
    image = "registry.bepis.lol/moonlight:2026-03-23";
    pull = "always";
    autoStart = true;
    login = {
      username = "beau";
      passwordFile = config.sops.secrets."docker-registry/pass".path;
      registry = "registry.bepis.lol";
    };
    ports = [
      "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}:3838"
    ];
    volumes = [
      "${dataRoot}/data:/data"
    ];
    environment = {
      MOONLIGHT_SERVER_MODE = "1";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    extraConfig = lib.mkForce ''
      client_max_body_size 4000m;
    '';
  };
}
