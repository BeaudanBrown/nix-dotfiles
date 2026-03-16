{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  beadsPackage = inputs.beads.packages.${pkgs.system}.default;
  passwordPath = "${config.hostSpec.home}/.config/beads/dolt-password";
  wrappedBeads = pkgs.symlinkJoin {
    name = "beads-wrapped";
    paths = [ beadsPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bd \
        --set-default BEADS_DOLT_SERVER_MODE 1 \
        --set-default BEADS_DOLT_SERVER_HOST ${config.custom.beads.server.host} \
        --set-default BEADS_DOLT_SERVER_PORT ${toString config.custom.beads.server.port} \
        --set-default BEADS_DOLT_SERVER_USER ${config.custom.beads.server.user} \
        --run 'if [ -r ${passwordPath} ]; then export BEADS_DOLT_PASSWORD="$(cat ${passwordPath})"; fi'
    '';
  };
in
{
  options.custom.beads.server = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "beads-db.bepis.lol";
      description = "Tailnet-only host name for the central Beads Dolt SQL server.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3307;
      description = "TCP port for the central Beads Dolt SQL server.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "SQL user used by `bd` when connecting to the central Beads server.";
    };
  };

  config = {
    environment.sessionVariables = {
      BEADS_DOLT_SERVER_MODE = "1";
      BEADS_DOLT_SERVER_HOST = config.custom.beads.server.host;
      BEADS_DOLT_SERVER_PORT = toString config.custom.beads.server.port;
      BEADS_DOLT_SERVER_USER = config.custom.beads.server.user;
    };

    environment.systemPackages = [
      wrappedBeads
      pkgs.dolt
    ];

    hmModules.primary = [
      (
        { config, ... }:
        {
          sops.secrets."beads/dolt-password" = {
            sopsFile = lib.custom.sopsFileForModule __curPos.file;
            path = "${config.home.homeDirectory}/.config/beads/dolt-password";
            mode = "0600";
          };
        }
      )
    ];
  };
}
