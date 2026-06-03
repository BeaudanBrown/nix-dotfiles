{
  config,
  pkgs,
  ...
}:
let
  port = 8787;
  dataDir = "/var/lib/thought-capture";

  thoughtCaptureServer = pkgs.writers.writePython3Bin "thought-capture-server" {
    flakeIgnore = [ "E501" ];
    libraries = with pkgs.python3Packages; [
      flask
      requests
    ];
  } (builtins.readFile ./thought_capture.py);
in
{
  environment.systemPackages = [ thoughtCaptureServer ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];

  systemd.services.thought-capture = {
    description = "Tailnet thought-capture service";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];

    environment = {
      THOUGHT_CAPTURE_DATA_DIR = dataDir;
      THOUGHT_CAPTURE_HOST = "0.0.0.0";
      THOUGHT_CAPTURE_PORT = toString port;
      THOUGHT_CAPTURE_STT_URL = "https://stt.bepis.lol/inference";
      THOUGHT_CAPTURE_LLM_BASE_URL = "https://litellm.bepis.lol/v1";
      THOUGHT_CAPTURE_LLM_MODEL = "gpt-5-mini";
      THOUGHT_CAPTURE_LLM_API_KEY_FILE = config.sops.secrets."pi/litellm_api".path;
      REQUESTS_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };

    serviceConfig = {
      Type = "simple";
      User = config.hostSpec.username;
      Group = config.users.users.${config.hostSpec.username}.group;
      StateDirectory = "thought-capture";
      ExecStart = "${thoughtCaptureServer}/bin/thought-capture-server";
      Restart = "on-failure";
      RestartSec = "2s";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
    };
  };
}
