{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.atticCache;
  cacheUrl = "${cfg.endpoint}/${cfg.cacheName}";
in
{
  options.custom.atticCache = {
    endpoint = lib.custom.mkOpt lib.types.str "https://attic.bepis.lol" "Public Attic API endpoint.";
    cacheName = lib.custom.mkOpt lib.types.str "fleet" "Attic cache used for fleet build outputs.";
    publicKey =
      lib.custom.mkOpt (lib.types.nullOr lib.types.str)
        "fleet:TNxcGzYWUdJ40m2sDImRHOzX8DTbwYW/j84IILK2lYE="
        "Attic cache public key, e.g. fleet:base64...";
    package = lib.custom.mkOpt lib.types.package pkgs.attic-client "Attic client package.";

    upload = {
      enable = lib.custom.mkBoolOpt false ''
        Run `attic watch-store` to automatically upload new local build outputs.

        Enable after creating the cache and adding the `attic/push-token` SOPS
        secret for every host that imports this common module.
      '';
      tokenSecretName =
        lib.custom.mkOpt lib.types.str "attic/push-token"
          "SOPS secret containing an Attic token with push access to the cache.";
    };
  };

  config = lib.mkMerge [
    {
      environment.systemPackages = [ cfg.package ];
    }

    (lib.mkIf (cfg.publicKey != null) {
      nix.settings = {
        substituters = lib.mkBefore [ cacheUrl ];
        trusted-public-keys = lib.mkBefore [ cfg.publicKey ];
      };
    })

    (lib.mkIf cfg.upload.enable {
      sops.secrets.${cfg.upload.tokenSecretName} = {
        sopsFile = lib.custom.sopsFileForModule __curPos.file;
        mode = "0400";
      };

      systemd.services.attic-watch-store = {
        description = "Upload new Nix store paths to the fleet Attic cache";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        environment = {
          HOME = "/var/lib/attic-watch-store";
          XDG_CONFIG_HOME = "/run/attic-watch-store/config";
        };

        serviceConfig = {
          RuntimeDirectory = "attic-watch-store";
          RuntimeDirectoryMode = "0700";
          StateDirectory = "attic-watch-store";
          Restart = "always";
          RestartSec = "30s";
          Type = "exec";
          UMask = "0077";
        };

        script = ''
          set -euo pipefail

          install -d -m 0700 "$XDG_CONFIG_HOME/attic"
          token="$(cat ${config.sops.secrets.${cfg.upload.tokenSecretName}.path})"
          cat > "$XDG_CONFIG_HOME/attic/config.toml" <<EOF
          default-server = "nas"

          [servers.nas]
          endpoint = "${cfg.endpoint}"
          token = "$token"
          EOF

          exec ${lib.getExe cfg.package} watch-store ${lib.escapeShellArg cfg.cacheName}
        '';
      };
    })
  ];
}
