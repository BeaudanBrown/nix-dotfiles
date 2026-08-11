{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "polls.bepis.lol";
  portKey = "rallly";
  network = "rallly";

  dataRoot = "/var/lib/rallly";
  postgresData = "${dataRoot}/postgres";
  garageMetadata = "${dataRoot}/garage-meta";
  garageData = "${dataRoot}/garage-data";

  containerNames = [
    "rallly-web"
    "rallly-db"
    "rallly-garage"
  ];

  networkOptions = alias: [ "--network-alias=${alias}" ];

  garageConfig = pkgs.writeText "rallly-garage.toml" ''
    metadata_dir = "/var/lib/garage/meta"
    data_dir = "/var/lib/garage/data"

    db_engine = "sqlite"
    replication_factor = 1
    rpc_bind_addr = "[::]:3901"

    [s3_api]
    api_bind_addr = "[::]:3900"
    s3_region = "garage"
    root_domain = ".s3.garage.localhost"

    [admin]
    api_bind_addr = "[::]:3903"
  '';

  secretNames = [
    "rallly/secret-password"
    "rallly/postgres-password"
    "rallly/s3-access-key"
    "rallly/s3-secret-key"
    "rallly/garage-rpc-secret"
    "rallly/smtp-env"
  ];
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = false;
    }
  ];

  sops.secrets = lib.genAttrs secretNames (name: {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
    restartUnits = lib.optional (name == "rallly/smtp-env") "podman-rallly-web.service";
  });

  sops.templates = {
    "rallly-web.env" = {
      mode = "0400";
      restartUnits = [ "podman-rallly-web.service" ];
      content = ''
        SECRET_PASSWORD=${config.sops.placeholder."rallly/secret-password"}
        DATABASE_URL=postgresql://rallly:${
          config.sops.placeholder."rallly/postgres-password"
        }@rallly-db:5432/rallly
        S3_ACCESS_KEY_ID=${config.sops.placeholder."rallly/s3-access-key"}
        S3_SECRET_ACCESS_KEY=${config.sops.placeholder."rallly/s3-secret-key"}
      '';
    };

    "rallly-db.env" = {
      mode = "0400";
      restartUnits = [ "podman-rallly-db.service" ];
      content = ''
        POSTGRES_PASSWORD=${config.sops.placeholder."rallly/postgres-password"}
      '';
    };

    "rallly-garage.env" = {
      mode = "0400";
      restartUnits = [ "podman-rallly-garage.service" ];
      content = ''
        GARAGE_RPC_SECRET=${config.sops.placeholder."rallly/garage-rpc-secret"}
        GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder."rallly/s3-access-key"}
        GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder."rallly/s3-secret-key"}
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataRoot} 0750 root root - -"
    "d ${postgresData} 0700 70 70 - -"
    "d ${garageMetadata} 0700 root root - -"
    "d ${garageData} 0700 root root - -"
  ];

  systemd.services = {
    rallly-network = {
      description = "Create the isolated Rallly container network";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ config.virtualisation.podman.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        podman network exists ${network} || podman network create ${network}
      '';
    };
  }
  // lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
    after = [ "rallly-network.service" ];
    requires = [ "rallly-network.service" ];
  });

  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers = {
    rallly-web = {
      # Rallly v4.12.1, pinned to the upstream multi-architecture manifest.
      image = "docker.io/lukevella/rallly:4.12.1@sha256:6049260ff6d3accd86730372a650b5e8063c373a09f253c45f7e4a8dc9202752";
      pull = "missing";
      autoStart = true;
      dependsOn = [
        "rallly-db"
        "rallly-garage"
      ];
      networks = [ network ];
      extraOptions = networkOptions "rallly-web";
      ports = [
        "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}:3000"
      ];
      environmentFiles = [
        config.sops.templates."rallly-web.env".path
        config.sops.secrets."rallly/smtp-env".path
      ];
      environment = {
        NEXT_PUBLIC_BASE_URL = "https://${domain}";
        SUPPORT_EMAIL = "rallly@bepis.lol";
        NOREPLY_EMAIL = "rallly@bepis.lol";
        INITIAL_ADMIN_EMAIL = config.hostSpec.email;
        ALLOWED_EMAILS = "${config.hostSpec.email},art.pitchford@gmail.com";
        EMAIL_LOGIN_ENABLED = "true";
        REGISTRATION_ENABLED = "true";
        S3_ENDPOINT = "http://rallly-garage:3900";
        S3_BUCKET_NAME = "rallly";
        S3_REGION = "garage";
      };
    };

    rallly-db = {
      # PostgreSQL 18 Alpine, pinned to the upstream multi-architecture manifest.
      image = "docker.io/library/postgres:18-alpine@sha256:9a8afca54e7861fd90fab5fdf4c42477a6b1cb7d293595148e674e0a3181de15";
      pull = "missing";
      autoStart = true;
      networks = [ network ];
      extraOptions = networkOptions "rallly-db";
      environmentFiles = [ config.sops.templates."rallly-db.env".path ];
      environment = {
        POSTGRES_USER = "rallly";
        POSTGRES_DB = "rallly";
      };
      volumes = [ "${postgresData}:/var/lib/postgresql" ];
    };

    rallly-garage = {
      # Garage v2.3.0, pinned to the upstream multi-architecture manifest.
      image = "docker.io/dxflrs/garage:v2.3.0@sha256:866bd13ed2038ba7e7190e840482bc27234c4afaf77be8cfa439ae088c1e4690";
      pull = "missing";
      autoStart = true;
      networks = [ network ];
      extraOptions = networkOptions "rallly-garage";
      environmentFiles = [ config.sops.templates."rallly-garage.env".path ];
      environment.GARAGE_DEFAULT_BUCKET = "rallly";
      cmd = [
        "/garage"
        "server"
        "--single-node"
        "--default-bucket"
      ];
      volumes = [
        "${garageConfig}:/etc/garage.toml:ro"
        "${garageMetadata}:/var/lib/garage/meta"
        "${garageData}:/var/lib/garage/data"
      ];
    };
  };
}
