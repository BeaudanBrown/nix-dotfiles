{ config, ... }:
let
  domain = "img.bepis.lol";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.immich.host;
      upstreamPort = toString config.services.immich.port;
      webSockets = true;
    }
  ];

  services.immich = {
    enable = true;
    settings = {
      server.externalDomain = "https://${domain}";
      job = {
        smartSearch.concurrency = 6;
      };
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
