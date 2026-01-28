{ ... }:
{
  # custom.ports.requests = [ { key = "invoiceshelf"; } ];

  # hostedServices = [
  #   {
  #     domain = "invoice.bepis.lol";
  #     upstreamPort = toString config.custom.ports.assigned.invoiceshelf;
  #     tailnet = true; # Tailnet-only access with ACME SSL
  #   }
  # ];

  # virtualisation.oci-containers.containers.invoiceshelf = {
  #   image = "invoiceshelf/invoiceshelf:latest";
  #   autoStart = true;
  #   ports = [
  #     "127.0.0.1:${toString config.custom.ports.assigned.invoiceshelf}:8080"
  #   ];
  #   volumes = [
  #     "invoiceshelf-storage:/var/www/html/storage"
  #     "invoiceshelf-modules:/var/www/html/Modules"
  #   ];
  #   environment = {
  #     APP_NAME = "InvoiceShelf";
  #     APP_ENV = "production";
  #     APP_DEBUG = "false";
  #     APP_URL = "https://invoice.bepis.lol";
  #     SESSION_DOMAIN = "invoice.bepis.lol";
  #     SANCTUM_STATEFUL_DOMAINS = "invoice.bepis.lol";
  #     DB_CONNECTION = "sqlite";
  #     DB_DATABASE = "/var/www/html/storage/app/database.sqlite";
  #   };
  # };

  # # Enable Podman for OCI containers
  # virtualisation.podman.enable = true;
}
