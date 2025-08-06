{ ... }:
{
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
    enable = true;
    acceleration = "rocm";
    loadModels = [
      "gpt-oss:20b"
    ];
  };
  services.nextjs-ollama-llm-ui = {
    enable = true;
    hostname = "0.0.0.0";
    ollamaUrl = "http://127.0.0.1:11434";
  };
  networking.firewall = {
    allowedTCPPorts = [
      3000
    ];
  };
}
