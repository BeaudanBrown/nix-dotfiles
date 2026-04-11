{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "chat.bepis.lol";
  portKey = "openwebui";
  litellmPortKey = "litellm";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.open-webui.host;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
      tailnet = false;
    }
  ];

  services.open-webui = {
    enable = true;
    package = pkgs.unstable.open-webui;

    host = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    stateDir = "/var/lib/open-webui";

    environment = {
      WEBUI_URL = "https://${domain}";
      OPENAI_API_BASE_URL = "http://127.0.0.1:${
        toString config.custom.ports.assigned.${litellmPortKey}
      }/v1";
      ENABLE_WEB_SEARCH = "True";
      ENABLE_SEARCH_QUERY_GENERATION = "True";
      WEB_SEARCH_ENGINE = "duckduckgo";
      WEB_SEARCH_RESULT_COUNT = "5";
      WEB_SEARCH_CONCURRENT_REQUESTS = "1";
      WEB_LOADER_CONCURRENT_REQUESTS = "5";
      WEB_LOADER_TIMEOUT = "15";
      WEB_FETCH_MAX_CONTENT_LENGTH = "20000";
      ENABLE_IMAGE_GENERATION = "True";
      IMAGE_GENERATION_ENGINE = "openai";
      IMAGE_GENERATION_MODEL = "gemini-2.5-flash-image";
      CHAT_STREAM_RESPONSE_CHUNK_MAX_BUFFER_SIZE = "20971520";
    };

    environmentFile = config.sops.secrets.openwebui.path;
  };

  # `services.open-webui` uses `DynamicUser = true`, so there is no stable
  # `open-webui` user to chown secrets to. systemd reads `EnvironmentFile=` as root.
  sops.secrets.openwebui = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
  };
}
