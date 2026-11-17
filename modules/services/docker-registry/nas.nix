{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "registry.bepis.lol";
  portKey = "docker-registry";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.dockerRegistry.listenAddress;
      upstreamPort = toString config.services.dockerRegistry.port;
      webSockets = false;
    }
  ];

  services.dockerRegistry = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    enableDelete = true;
    enableGarbageCollect = true;
    garbageCollectDates = "weekly";
    extraConfig = {
      # Authenticate the loopback backend too; nginx alone is bypassable by
      # local users. Existing entries MUST use bcrypt (verify before switch).
      auth.htpasswd = {
        realm = "Private Docker Registry";
        path = "/run/credentials/docker-registry.service/htpasswd";
      };
      http.headers = {
        "X-Content-Type-Options" = [ "nosniff" ];
      };
    };
  };

  systemd.services.docker-registry = {
    serviceConfig.LoadCredential = [
      "htpasswd:${config.sops.secrets."docker-registry/htpasswd".path}"
    ];
    # Native Distribution auth only accepts bcrypt. Refuse incompatible files
    # without printing usernames/hashes; the operator must migrate them first.
    preStart = lib.mkBefore ''
      if ! ${pkgs.gawk}/bin/awk -F: '
        NF != 2 || $2 !~ /^\$2[aby]\$[0-9][0-9]\$[./A-Za-z0-9]{53}$/ { bad = 1 }
        END { exit (NR == 0 || bad) }
      ' "$CREDENTIALS_DIRECTORY/htpasswd"; then
        echo "Registry htpasswd must contain nonempty bcrypt entries before activation" >&2
        exit 1
      fi
    '';
  };

  services.nginx.virtualHosts.${domain} = {
    locations."/v2/" = {
      proxyPass = "http://127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
      extraConfig = ''
        # Keep the existing frontend challenge; Authorization also reaches
        # the now-authenticated backend.
        auth_basic "Private Docker Registry";
        auth_basic_user_file ${config.sops.secrets."docker-registry/htpasswd".path};

        # Required for large uploads/pushes
        client_max_body_size 0;
        proxy_read_timeout 900s;
        proxy_request_buffering off;
      '';
    };
  };

  sops.secrets."docker-registry/htpasswd" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    # Keep it in /etc so it's available early and readable by nginx
    # path = "/etc/secrets/docker-registry/htpasswd";
    mode = "0640";
    owner = "nginx";
    group = "nginx";
  };
}
