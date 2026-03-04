{
  config,
  lib,
  pkgs,
  ...
}:
let
  portKey = "voice-assistant";
  litellmPortKey = "litellm";

  # Build the voice-assistant as a proper Python application using nixpkgs writers
  voice-assistant-app = pkgs.writers.writePython3Bin "voice-assistant" {
    libraries = with pkgs.python3Packages; [ flask ];
    doCheck = false;
  } (builtins.readFile ./voice_assistant.py);
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      domain = "assistant.bepis.lol";
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = true; # Tailnet-only for privacy
      webSockets = false;
    }
  ];

  users.groups.voice-assistant = { };
  users.users.voice-assistant = {
    isSystemUser = true;
    group = "voice-assistant";
    description = "Voice Assistant Service";
  };

  systemd.services.voice-assistant = {
    description = "Voice Assistant LLM Proxy";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "litellm.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "voice-assistant";
      Group = "voice-assistant";

      ExecStart = "${voice-assistant-app}/bin/voice-assistant";

      Environment = [
        "PORT=${toString config.custom.ports.assigned.${portKey}}"
        "LITELLM_URL=http://127.0.0.1:${
          toString config.custom.ports.assigned.${litellmPortKey}
        }/v1/chat/completions"
      ];
      EnvironmentFile = config.sops.secrets."voice_assistant/env".path;

      Restart = "on-failure";
      RestartSec = "5s";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
    };
  };

  sops.secrets."voice_assistant/env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "voice-assistant";
    group = "voice-assistant";
  };
}
