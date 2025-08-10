{ config, ... }:
{
  services.nginx.virtualHosts."img.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${config.services.immich.host}:${toString config.services.immich.port}";
    };
  };
  services.immich = {
    enable = false;
    settings = {
      server.externalDomain = "img.bepis.lol";
    };
    machine-learning = {
      enable = true;
      # environment = {
      #   HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
      # };
    };
  };
}
