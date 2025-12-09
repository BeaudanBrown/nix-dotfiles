{ config, ... }:
let
  domain = "invoice.bepis.lol";
  portKey = "invoiceshelf";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = true; # Tailnet-only access with ACME SSL
    }
  ];

  virtualisation.oci-containers.containers.invoiceshelf = {
    image = "invoiceshelf/invoiceshelf:nightly";
    autoStart = true;
    ports = [
      "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}:8080"
    ];
    volumes = [
      "invoiceshelf-storage:/var/www/html/storage"
      "invoiceshelf-modules:/var/www/html/Modules"
    ];
    environment = {
      APP_NAME = "InvoiceShelf";
      APP_ENV = "production";
      APP_DEBUG = "false";
      APP_URL = "https://${domain}";
      SESSION_DOMAIN = domain;
      SANCTUM_STATEFUL_DOMAINS = domain;
      DB_CONNECTION = "sqlite";
      DB_DATABASE = "/var/www/html/storage/app/database.sqlite";
    };
  };

  # Enable Podman for OCI containers
  virtualisation.podman.enable = true;
}
