{
  config,
  pkgs,
  ...
}:
let
  portKey = "stt";
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin";
    hash = "sha256-kh5M+Ghv3Zk9zQgaXaW2w2W/3hFi5ysI11rHUomSCx8=";
  };
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      domain = "stt.bepis.lol";
      tailnet = true;
      webSockets = false;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
    }
  ];

  users.groups.stt = { };
  users.users.stt = {
    isSystemUser = true;
    group = "stt";
  };

  systemd.services.stt-whisper-server = {
    description = "Whisper.cpp inference server (STT)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "stt";
      Group = "stt";

      ExecStart =
        "${pkgs.whisper-cpp}/bin/whisper-server "
        + "--host 127.0.0.1 "
        + "--port ${toString config.custom.ports.assigned.${portKey}} "
        + "--inference-path /inference "
        + "--language en "
        + "--model ${model} "
        + "--no-timestamps "
        + "--max-context 0 "
        + "--best-of 1 "
        + "--beam-size 1";

      Restart = "on-failure";
      RestartSec = "1s";

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
}
