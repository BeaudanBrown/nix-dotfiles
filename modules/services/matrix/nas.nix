{
  config,
  lib,
  ...
}:
let
  domain = "matrix.bepis.lol";
  userId = "@${config.hostSpec.username}:${domain}";
  synapsePortKey = "matrix-synapse";
  signalPortKey = "mautrix-signal";
  facebookPortKey = "mautrix-facebook";
in
{
  custom.ports.requests = [
    { key = synapsePortKey; }
    { key = signalPortKey; }
    { key = facebookPortKey; }
  ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${synapsePortKey};
      webSockets = true;
    }
  ];

  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ config.sops.secrets."matrix/synapse-extra-config".path ];
    settings = {
      server_name = domain;
      public_baseurl = "https://${domain}/";
      report_stats = false;
      enable_registration = false;
      max_upload_size = "100M";
      presence.enabled = true;
      url_preview_enabled = true;
      listeners = [
        {
          port = config.custom.ports.assigned.${synapsePortKey};
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [ "client" ];
              compress = true;
            }
            {
              names = [ "federation" ];
              compress = false;
            }
          ];
        }
      ];
      database = {
        name = "psycopg2";
        args = {
          database = "matrix-synapse";
          user = "matrix-synapse";
          host = "/run/postgresql";
        };
      };
    };
  };

  services.mautrix-signal = {
    enable = true;
    registerToSynapse = true;
    environmentFile = config.sops.secrets."matrix/mautrix-signal-env".path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:${toString config.custom.ports.assigned.${synapsePortKey}}";
        domain = domain;
      };
      appservice = {
        hostname = "127.0.0.1";
        port = config.custom.ports.assigned.${signalPortKey};
      };
      database = {
        type = "postgres";
        uri = "postgresql:///mautrix-signal?host=/run/postgresql";
      };
      bridge = {
        permissions = {
          "*" = "relay";
          ${domain} = "relay";
          ${userId} = "admin";
        };
      };
      encryption = {
        allow = true;
        default = true;
        require = true;
        pickle_key = "$MAUTRIX_SIGNAL_PICKLE_KEY";
      };
      provisioning.shared_secret = "$MAUTRIX_SIGNAL_PROVISIONING_SHARED_SECRET";
    };
  };

  services.mautrix-meta.instances.facebook = {
    enable = true;
    environmentFile = config.sops.secrets."matrix/mautrix-facebook-env".path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:${toString config.custom.ports.assigned.${synapsePortKey}}";
        domain = domain;
      };
      appservice = {
        port = config.custom.ports.assigned.${facebookPortKey};
        bot.username = "facebookbot";
      };
      network.mode = "facebook";
      database = {
        type = "postgres";
        uri = "postgresql:///mautrix-meta-facebook?host=/run/postgresql";
      };
      bridge.permissions = {
        ${userId} = "admin";
      };
      encryption.pickle_key = "$MAUTRIX_FACEBOOK_PICKLE_KEY";
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [
      "matrix-synapse"
      "mautrix-signal"
      "mautrix-meta-facebook"
    ];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
      {
        name = "mautrix-signal";
        ensureDBOwnership = true;
      }
      {
        name = "mautrix-meta-facebook";
        ensureDBOwnership = true;
      }
    ];
    authentication = ''
      local all all trust
      host all all 127.0.0.1/32 trust
      host all all ::1/128 trust
    '';
  };

  sops.secrets."matrix/synapse-extra-config" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "matrix-synapse";
    group = "matrix-synapse";
    mode = "0400";
    # Populate with YAML, for example:
    # registration_shared_secret: "<random-secret-for-register_new_matrix_user>"
  };

  sops.secrets."matrix/mautrix-signal-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "mautrix-signal";
    group = "mautrix-signal";
    mode = "0400";
    # Populate as an env file:
    # MAUTRIX_SIGNAL_PICKLE_KEY=<random-stable-secret>
    # MAUTRIX_SIGNAL_PROVISIONING_SHARED_SECRET=<random-stable-secret-or-disable>
    # Optional double puppeting:
    # MAUTRIX_SIGNAL_BRIDGE_LOGIN_SHARED_SECRET=<random-stable-secret>
  };

  sops.secrets."matrix/mautrix-facebook-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "mautrix-meta-facebook";
    group = "mautrix-meta";
    mode = "0400";
    # Populate as an env file:
    # MAUTRIX_FACEBOOK_PICKLE_KEY=<random-stable-secret>
  };

  # Slack first-pass note: nixpkgs packages pkgs.mautrix-slack, but your current
  # channel has no services.mautrix-slack module. Add it in a follow-up with a
  # small systemd wrapper/registration service.
}
