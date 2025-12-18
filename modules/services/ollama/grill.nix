{ config, pkgs, ... }:
{
  services.nginx.virtualHosts."llm.grill.lan" = {
    forceSSL = true;
    useACMEHost = "grill.lan";
    locations."/" = {
      proxyPass = "http://${config.services.nextjs-ollama-llm-ui.hostName}:${toString config.services.nextjs-ollama-llm-ui.port}";
      proxyWebsockets = true;
    };
  };
  nixpkgs.overlays = [
    (final: prev: {
      ollama = prev.ollama.overrideAttrs (oldAttrs: rec {
        version = "0.11.2";
        src = prev.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          tag = "v${version}";
          hash = "sha256-NZaaCR6nD6YypelnlocPn/43tpUz0FMziAlPvsdCb44=";
          fetchSubmodules = true;
        };
        vendorHash = "sha256-SlaDsu001TUW+t9WRp7LqxUSQSGDF1Lqu9M1bgILoX4=";
      });
    })
  ];
  services.ollama = {
    enable = false;
    package = pkgs.ollama-rocm;
    port = 11111;
    # port = config.custom.ports.assigned.${portKey};
    loadModels = [
      "gpt-oss:20b"
    ];
    environmentVariables = {
      OLLAMA_GPU_OVERHEAD = "1610612736";
      OLLAMA_NUM_PARALLEL = "1";
    };
  };
  services.nextjs-ollama-llm-ui = {
    enable = true;
    hostname = "127.0.0.1";
    port = 11112;
    ollamaUrl = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
  };
}
