{ config, ... }:
{
  services.nginx.virtualHosts."img.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${config.services.immich.host}:${toString config.services.immich.port}";
      proxyWebsockets = true;
    };
  };
  services.immich = {
    enable = true;
    settings = {
      server.externalDomain = "https://img.bepis.lol";
      machineLearning = {
        enabled = true;
        urls = [
          "http://127.0.0.1:3003"
        ];
        clip = {
          enabled = true;
          # modelName = "ViT-B-32__openai";
          modelName = "ViT-SO400M-16-SigLIP2-384__webli";
        };
        duplicateDetection = {
          enabled = true;
          maxDistance = 0.01;
        };
        facialRecognition = {
          enabled = true;
          modelName = "buffalo_l";
          minScore = 0.3;
          maxDistance = 0.4;
          minFaces = 10;
        };
      };
    };
    machine-learning = {
      enable = true;
      environment = {
        HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
      };
    };
  };
}
