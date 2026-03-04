{ config, pkgs, ... }:
let
  qdrantHttpKey = "qdrant-http";
  qdrantGrpcKey = "qdrant-grpc";
  ragMcpKey = "rag-mcp";
  qdrantDomain = "qdrant.bepis.lol";
  ragMcpDomain = "rag-mcp.bepis.lol";
  projectsRoot = "/pool1/appdata/rag/projects";
  rag-indexer = pkgs.writers.writePython3Bin "rag-indexer" {
    libraries = with pkgs.python3Packages; [
      openai
      qdrant-client
    ];
    doCheck = false;
  } (builtins.readFile ./rag-indexer.py);
  rag-mcp-server = pkgs.writers.writePython3Bin "rag-mcp-server" {
    libraries = with pkgs.python3Packages; [
      fastmcp
      openai
      qdrant-client
    ];
    doCheck = false;
  } (builtins.readFile ./rag-mcp-server.py);
in
{
  custom.ports.requests = [
    { key = qdrantHttpKey; }
    { key = qdrantGrpcKey; }
    { key = ragMcpKey; }
  ];

  hostedServices = [
    {
      domain = qdrantDomain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${qdrantHttpKey};
      tailnet = true;
    }
    {
      domain = ragMcpDomain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${ragMcpKey};
      tailnet = true;
      webSockets = true;
    }
  ];

  systemd.tmpfiles.rules = [
    "d /pool1/appdata/rag 0750 ${config.hostSpec.username} ${
      config.users.users.${config.hostSpec.username}.group
    } - -"
    "d ${projectsRoot} 0750 ${config.hostSpec.username} ${
      config.users.users.${config.hostSpec.username}.group
    } - -"
  ];

  environment.systemPackages = [
    rag-indexer
  ];

  services.qdrant = {
    enable = true;
    settings = {
      service = {
        host = "127.0.0.1";
        http_port = config.custom.ports.assigned.${qdrantHttpKey};
        grpc_port = config.custom.ports.assigned.${qdrantGrpcKey};
      };
      telemetry_disabled = true;
    };
  };

  # ── RAG MCP server (SSE transport) ────────────────────────────────
  systemd.services.rag-mcp = {
    description = "RAG MCP server (SSE)";
    after = [
      "network-online.target"
      "litellm.service"
      "qdrant.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = config.hostSpec.username;
      Group = config.users.users.${config.hostSpec.username}.group;
      ExecStart = "${rag-mcp-server}/bin/rag-mcp-server";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "RAG_MCP_HOST=127.0.0.1"
        "RAG_MCP_PORT=${toString config.custom.ports.assigned.${ragMcpKey}}"
        "RAG_QDRANT_URL=http://127.0.0.1:${toString config.custom.ports.assigned.${qdrantHttpKey}}"
        "RAG_QDRANT_TIMEOUT=120"
        "RAG_COLLECTION=rag_chunks"
        "RAG_EMBEDDING_MODEL=openai/text-embedding-3-small"
        "LITELLM_BASE_URL=http://127.0.0.1:${toString config.custom.ports.assigned.litellm}/v1"
        "LITELLM_API_KEY_FILE=${config.sops.secrets.litellm_api.path}"
        "RAG_PROJECTS_ROOT=${projectsRoot}"
        "RAG_INDEXER_CMD=RAG_STATE_FILE=/pool1/appdata/rag/state.json ${rag-indexer}/bin/rag-indexer --scan"
      ];
    };
  };

  # ── RAG PDF indexer (timer-based) ─────────────────────────────────
  systemd.services.rag-indexer = {
    description = "RAG PDF indexer";
    after = [
      "network-online.target"
      "litellm.service"
      "qdrant.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = config.hostSpec.username;
      Group = config.users.users.${config.hostSpec.username}.group;
      ExecStart = "${rag-indexer}/bin/rag-indexer --scan";
      Environment = [
        "RAG_PROJECTS_ROOT=${projectsRoot}"
        "RAG_COLLECTION=rag_chunks"
        "RAG_QDRANT_URL=http://127.0.0.1:${toString config.custom.ports.assigned.${qdrantHttpKey}}"
        "RAG_EMBEDDING_MODEL=openai/text-embedding-3-small"
        "RAG_EMBED_BATCH_SIZE=32"
        "RAG_UPSERT_BATCH_SIZE=128"
        "RAG_QDRANT_TIMEOUT=120"
        "LITELLM_BASE_URL=http://127.0.0.1:${toString config.custom.ports.assigned.litellm}/v1"
        "LITELLM_API_KEY_FILE=${config.sops.secrets.litellm_api.path}"
        "PDFTOTEXT_BIN=${pkgs.poppler-utils}/bin/pdftotext"
        "RAG_STATE_FILE=/pool1/appdata/rag/state.json"
      ];
    };
  };

  systemd.timers.rag-indexer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "15m";
      Unit = "rag-indexer.service";
    };
  };
}
