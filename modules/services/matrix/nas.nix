{
  config,
  lib,
  ...
}:
let
  domain = "matrix.bepis.lol";
  userId = "@${config.hostSpec.username}:${domain}";
  synapsePortKey = "matrix-synapse";
  signalPort = 29328;
  facebookPort = 29321;
in
{
  custom.ports.requests = [ { key = synapsePortKey; } ];

  custom.ports.reserved = [
    signalPort
    facebookPort
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
      experimental_features = {
        msc3202_transaction_extensions = true;
        msc2409_to_device_messages_enabled = true;
      };
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
        port = signalPort;
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
        # Keep bridge rooms unencrypted until MSC4350 lands in mautrix/Synapse.
        # https://github.com/mautrix/go/pull/512
        # https://github.com/matrix-org/matrix-spec-proposals/pull/4350
        allow = false;
        default = false;
        require = false;
        appservice = false;
        msc4190 = false;
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
        hostname = "127.0.0.1";
        port = facebookPort;
        address = "http://127.0.0.1:${toString facebookPort}";
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
      encryption = {
        allow = false;
        default = false;
        require = false;
        appservice = false;
        msc4190 = false;
        pickle_key = "$MAUTRIX_FACEBOOK_PICKLE_KEY";
      };
    };
  };

  systemd.services = {
    matrix-synapse-db-init = {
      description = "Create Synapse PostgreSQL database with C collation";
      requires = [ "postgresql-setup.service" ];
      after = [ "postgresql-setup.service" ];
      before = [ "matrix-synapse.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        psql=${config.services.postgresql.package}/bin/psql
        createdb=${config.services.postgresql.package}/bin/createdb
        dropdb=${config.services.postgresql.package}/bin/dropdb

        create_synapse_db() {
          $createdb --owner=matrix-synapse --encoding=UTF8 --locale=C --template=template0 matrix-synapse
        }

        db_exists="$($psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'matrix-synapse'")"
        if [ "$db_exists" != "1" ]; then
          create_synapse_db
        fi

        collation="$($psql -d postgres -tAc "SELECT datcollate FROM pg_database WHERE datname = 'matrix-synapse'")"
        if [ "$collation" != "C" ]; then
          object_count="$($psql -d matrix-synapse -tAc "
            SELECT count(*)
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
              AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
          ")"

          if [ "$object_count" = "0" ]; then
            echo "Recreating empty matrix-synapse database with C collation."
            $dropdb matrix-synapse
            create_synapse_db
          else
            echo "matrix-synapse database has collation '$collation', but Synapse requires 'C'." >&2
            echo "It contains $object_count objects, so refusing to recreate it automatically." >&2
            echo "Migrate it manually or back it up, drop it, and rerun activation." >&2
            exit 1
          fi
        fi
      '';
    };
    matrix-synapse = {
      requires = [ "matrix-synapse-db-init.service" ];
      after = [ "matrix-synapse-db-init.service" ];
    };
    mautrix-signal = {
      requires = [
        "postgresql-setup.service"
        "matrix-synapse.service"
      ];
      after = [
        "postgresql-setup.service"
        "matrix-synapse.service"
      ];
    };
    mautrix-meta-facebook = {
      requires = [
        "postgresql-setup.service"
        "matrix-synapse.service"
      ];
      after = [
        "postgresql-setup.service"
        "matrix-synapse.service"
      ];
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [
      "mautrix-signal"
      "mautrix-meta-facebook"
    ];
    ensureUsers = [
      { name = "matrix-synapse"; }
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
    # Appservice tokens are generated into /var/lib/mautrix-meta-facebook/meta-registration.yaml.
  };

  # Slack first-pass note: nixpkgs packages pkgs.mautrix-slack, but your current
  # channel has no services.mautrix-slack module. Add it in a follow-up with a
  # small systemd wrapper/registration service.
}
