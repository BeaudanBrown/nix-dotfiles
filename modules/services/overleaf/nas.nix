{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "leaf.bepis.lol";
  portKey = "overleaf";
  network = "overleaf";
  dataRoot = "/var/lib/overleaf";
  sharelatexData = "${dataRoot}/sharelatex";
  mongoData = "${dataRoot}/mongo";
  redisData = "${dataRoot}/redis";
  gitBridgeData = "${dataRoot}/git-bridge";

  containerNames = [
    "overleaf-sharelatex"
    "overleaf-mongo"
    "overleaf-redis"
    "overleaf-git-bridge"
  ];

  networkOptions = alias: [
    "--network-alias=${alias}"
  ];

  mongoReplicaSetInit = pkgs.writeText "mongodb-init-replica-set.js" ''
    /* eslint-disable no-undef */
    rs.initiate({ _id: 'overleaf', members: [{ _id: 0, host: 'mongo:27017' }] })
  '';

in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
      tailnet = false;
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${dataRoot} 0750 root root - -"
    "d ${sharelatexData} 0750 root root - -"
    "d ${sharelatexData}/data 0750 root root - -"
    "d ${sharelatexData}/data/compiles 0750 root root - -"
    "d ${sharelatexData}/data/output 0750 root root - -"
    "d ${mongoData} 0750 root root - -"
    "d ${redisData} 0750 root root - -"
    "d ${gitBridgeData} 0750 root root - -"
  ];

  systemd.services = {
    overleaf-network = {
      description = "Create the Overleaf container network";
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
    after = [ "overleaf-network.service" ];
    requires = [ "overleaf-network.service" ];
  });

  virtualisation.oci-containers.containers = {
    overleaf-sharelatex = {
      image = "overleafcep/sharelatex:6.1.2-ext-v4.1";
      pull = "missing";
      dependsOn = [
        "overleaf-mongo"
        "overleaf-redis"
      ];
      networks = [ network ];
      ports = [
        "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}:80"
      ];
      volumes = [
        "${sharelatexData}:/var/lib/overleaf"
        "/var/run/docker.sock:/var/run/docker.sock"
      ];
      environment = {
        OVERLEAF_APP_NAME = "Overleaf CE+";
        OVERLEAF_SITE_URL = "https://${domain}";
        OVERLEAF_NAV_TITLE = "leaf.bepis.lol";
        OVERLEAF_ADMIN_EMAIL = "beaudan.brown@gmail.com";
        OVERLEAF_MONGO_URL = "mongodb://mongo/sharelatex";
        OVERLEAF_REDIS_HOST = "redis";
        REDIS_HOST = "redis";
        ENABLED_LINKED_FILE_TYPES = "project_file,project_output_file,zotero";
        ENABLE_CONVERSIONS = "true";
        EMAIL_CONFIRMATION_DISABLED = "true";

        SANDBOXED_COMPILES = "true";
        SANDBOXED_COMPILES_HOST_DIR_COMPILES = "${sharelatexData}/data/compiles";
        SANDBOXED_COMPILES_HOST_DIR_OUTPUT = "${sharelatexData}/data/output";
        DOCKER_RUNNER = "true";
        SANDBOXED_COMPILES_SIBLING_CONTAINERS = "true";

        GIT_BRIDGE_ENABLED = "true";
        GIT_BRIDGE_HOST = "git-bridge";
        GIT_BRIDGE_PORT = "8000";
        V1_HISTORY_URL = "http://sharelatex:3100/api";
      };
      extraOptions = networkOptions "sharelatex";
    };

    overleaf-mongo = {
      image = "mongo:6.0";
      pull = "missing";
      networks = [ network ];
      cmd = [
        "--replSet"
        "overleaf"
      ];
      volumes = [
        "${mongoData}:/data/db"
        "${mongoReplicaSetInit}:/docker-entrypoint-initdb.d/mongodb-init-replica-set.js:ro"
      ];
      environment = {
        MONGO_INITDB_DATABASE = "sharelatex";
      };
      extraOptions = (networkOptions "mongo") ++ [
        "--add-host=mongo:127.0.0.1"
      ];
    };

    overleaf-redis = {
      image = "redis:6.2";
      pull = "missing";
      networks = [ network ];
      volumes = [
        "${redisData}:/data"
      ];
      extraOptions = networkOptions "redis";
    };

    overleaf-git-bridge = {
      image = "quay.io/sharelatex/git-bridge:6.1.2";
      pull = "missing";
      dependsOn = [ "overleaf-sharelatex" ];
      networks = [ network ];
      user = "root";
      cmd = [ "/server-pro-start.sh" ];
      volumes = [
        "${gitBridgeData}:/data/git-bridge"
      ];
      environment = {
        GIT_BRIDGE_API_BASE_URL = "http://sharelatex:3000/api/v0/";
        GIT_BRIDGE_OAUTH2_SERVER = "http://sharelatex";
        GIT_BRIDGE_POSTBACK_BASE_URL = "http://git-bridge:8000";
        GIT_BRIDGE_ROOT_DIR = "/data/git-bridge";
      };
      extraOptions = networkOptions "git-bridge";
    };
  };
}
