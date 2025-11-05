{
  config,
  pkgsStable,
  ...
}:
let
  domain = "pdf.bepis.lol";
  portKey = "docling";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.docling-serve.host;
      upstreamPort = toString config.services.docling-serve.port;
    }
  ];

  services.docling-serve = {
    enable = true;
    package = pkgsStable.docling-serve.override {
      withUI = true;
      withTesserocr = true;
      withCPU = true;
      withRapidocr = true;
    };
    port = config.custom.ports.assigned.${portKey};
    environment = {
      DOCLING_SERVE_ENABLE_UI = "True";
      # Disable Gradio telemetry and ensure single-process state consistency
      GRADIO_ANALYTICS_ENABLED = "False";
      UVICORN_WORKERS = "1";
    };
  };
}
