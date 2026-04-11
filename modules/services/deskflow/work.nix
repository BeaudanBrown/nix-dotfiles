{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.deskflow;
  screensConfig = cfg.screens |> map (s: "  ${s}:") |> lib.concatStringsSep "\n";
  screenLinksConfig =
    cfg.screenLinks
    |> lib.mapAttrsToList (
      screen: links:
      ''
        ${screen}:
      ''
      + (links |> lib.mapAttrsToList (dir: target: "    ${dir} = ${target}") |> lib.concatStringsSep "\n")
    )
    |> lib.concatStringsSep "\n";
in
{
  options.services.deskflow = {
    enable = lib.mkEnableOption "Deskflow keyboard/mouse sharing";

    package = lib.mkOption {
      default = pkgs.deskflow;
      description = "Deskflow package to use";
    };

    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "client"
      ];
      description = "Whether this machine acts as server or client";
    };

    serverAddress = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Server address for client to connect to (IP:port)";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 24800;
      description = "Port for Deskflow server to listen on";
    };

    screenName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Screen name to identify this machine";
    };

    screens = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of screen names in the configuration (server only)";
    };

    screenLinks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      description = "Screen link configuration mapping screens to their neighbors";
      example = {
        grill = {
          left = "t480";
        };
        t480 = {
          right = "grill";
        };
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration to append to deskflow-server.conf";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.deskflow ];
    networking.firewall.allowedTCPPorts = [ cfg.port ];
    systemd.tmpfiles.rules = [
      "d ${config.hostSpec.home}/.config/Deskflow 0700 ${config.hostSpec.username} users - -"
    ];

    # =========================== Client =======================================

    systemd.user.services.deskflow-client = lib.mkIf (cfg.role == "client") {
      description = "Deskflow client";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStart = ''
          ${cfg.package}/bin/deskflow-core client --no-daemon --name ${lib.escapeShellArg cfg.screenName} ${lib.escapeShellArg cfg.serverAddress}
        '';
        Restart = "always";
        RestartSec = 3;
      };
    };

    # =========================== Server =======================================

    systemd.user.services.deskflow-server = lib.mkIf (cfg.role == "server") {
      description = "Deskflow server";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStart = ''
          ${cfg.package}/bin/deskflow-core server --no-daemon --name ${lib.escapeShellArg cfg.screenName} --address ${lib.escapeShellArg ":${toString cfg.port}"} --config ${lib.escapeShellArg "${config.hostSpec.home}/.config/Deskflow/deskflow-server.conf"}
        '';
        Restart = "always";
        RestartSec = 3;
      };
    };

    hm.primary.xdg.configFile."Deskflow/deskflow-server.conf" = lib.mkIf (cfg.role == "server") {
      text = ''
        section: screens
        ${screensConfig}
        end

        section: links
        ${screenLinksConfig}
        end
      '';
    };
  };
}
