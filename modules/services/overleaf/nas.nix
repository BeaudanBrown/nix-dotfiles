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
  texliveImage = "texlive/texlive:latest-full";

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

  nginxPodmanResolverPatch = pkgs.writeTextFile {
    name = "overleaf-nginx-podman-resolver.sh";
    executable = true;
    text = ''
      #!/bin/bash
      set -euo pipefail

      resolver="$(awk '/^nameserver / { print $2; exit }' /etc/resolv.conf)"
      if [ -n "$resolver" ]; then
        sed -i "s/resolver 127\.0\.0\.11 valid=10s;/resolver $resolver valid=10s;/" \
          /etc/nginx/templates/overleaf.conf.template
      fi
    '';
  };

in
{
  custom.ports.requests = [ { key = portKey; } ];

  sops.secrets."overleaf/env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
  };

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
    "d ${sharelatexData} 0750 33 33 - -"
    "d ${sharelatexData}/data 0750 33 33 - -"
    "d ${sharelatexData}/data/compiles 0750 33 33 - -"
    "d ${sharelatexData}/data/output 0750 33 33 - -"
    "d ${sharelatexData}/tmp 0750 33 33 - -"
    "d ${sharelatexData}/tmp/uploads 0750 33 33 - -"
    "d ${mongoData} 0750 root root - -"
    "d ${redisData} 0750 999 999 - -"
    "d ${gitBridgeData} 0750 1000 1000 - -"
    "d ${gitBridgeData}/.wlgb 0750 1000 1000 - -"
    "d ${gitBridgeData}/.wlgb/atts 0750 1000 1000 - -"
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

    overleaf-texlive-image = {
      description = "Ensure Overleaf TeX Live compile image is available";
      wantedBy = [ "multi-user.target" ];
      after = [
        "docker.service"
        "network-online.target"
      ];
      requires = [
        "docker.service"
        "network-online.target"
      ];
      path = [ config.virtualisation.docker.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker image inspect ${texliveImage} >/dev/null 2>&1 || docker pull ${texliveImage}
      '';
    };
  }
  // lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
    after = [
      "overleaf-network.service"
      "overleaf-texlive-image.service"
    ];
    requires = [
      "overleaf-network.service"
      "overleaf-texlive-image.service"
    ];
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
        "${nginxPodmanResolverPatch}:/etc/my_init.d/199_set_nginx_podman_resolver.sh:ro"
      ];
      environmentFiles = [ config.sops.secrets."overleaf/env".path ];
      environment = {
        OVERLEAF_APP_NAME = "Overleaf CE+";
        OVERLEAF_SITE_URL = "https://${domain}";
        OVERLEAF_NAV_TITLE = "leaf.bepis.lol";
        OVERLEAF_ADMIN_EMAIL = "beaudan.brown@gmail.com";
        OVERLEAF_BEHIND_PROXY = "true";
        OVERLEAF_SECURE_COOKIE = "true";
        OVERLEAF_TRUSTED_PROXY_IPS = "loopback,127.0.0.1";
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
        ALL_TEX_LIVE_DOCKER_IMAGES = texliveImage;
        TEX_LIVE_DOCKER_IMAGE = texliveImage;

        GIT_BRIDGE_ENABLED = "true";
        GIT_BRIDGE_HOST = "git-bridge";
        GIT_BRIDGE_PORT = "8000";
        V1_HISTORY_URL = "http://sharelatex:3100/api";
      };
      extraOptions = networkOptions "sharelatex";
    };

    overleaf-mongo = {
      image = "mongo:8.0";
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
