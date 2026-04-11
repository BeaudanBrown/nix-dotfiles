{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.lanMouse;
  tomlFormat = pkgs.formats.toml { };
  configFile = tomlFormat.generate "lan-mouse-config.toml" (
    {
      port = cfg.port;
      clients = map (
        client:
        {
          inherit (client) ips position;
          activate_on_startup = client.activateOnStartup;
        }
        // lib.optionalAttrs (client.hostname != null) { inherit (client) hostname; }
        // lib.optionalAttrs (client.port != null) { inherit (client) port; }
      ) cfg.clients;
    }
    // lib.optionalAttrs (cfg.releaseBind != [ ]) {
      release_bind = cfg.releaseBind;
    }
    // lib.optionalAttrs (cfg.authorizedFingerprints != { }) {
      authorized_fingerprints = cfg.authorizedFingerprints;
    }
  );
in
{
  options.services.lanMouse = {
    enable = lib.mkEnableOption "Lan Mouse keyboard and pointer sharing";

    package = lib.mkOption {
      default = pkgs.lan-mouse;
      description = "Lan Mouse package to use";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4242;
      description = "UDP port used by Lan Mouse";
    };

    releaseBind = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Optional release bind keys to ungrab the pointer";
    };

    authorizedFingerprints = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Persisted Lan Mouse peer certificate fingerprints";
    };

    clients = lib.mkOption {
      default = [ ];
      description = "Peer clients and their relative positions";
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            position = lib.mkOption {
              type = lib.types.enum [
                "left"
                "right"
                "top"
                "bottom"
              ];
              description = "Relative position of the peer client";
            };

            hostname = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional hostname for the peer client";
            };

            ips = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Known IP addresses for the peer client";
            };

            activateOnStartup = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the peer should be active immediately on startup";
            };

            port = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = "Optional per-client port override";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    networking.firewall.allowedUDPPorts = [ cfg.port ];

    systemd.user.services.lan-mouse = {
      description = "Lan Mouse";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/lan-mouse --daemon --frontend cli --config ${configFile}";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };

    hm.primary.xdg.configFile."lan-mouse/config.toml".source = configFile;
  };
}
