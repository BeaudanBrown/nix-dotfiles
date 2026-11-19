{
  config,
  lib,
  pkgs,
  ...
}:
{
  hostedServices = [
    {
      domain = "auth.bepis.lol";
      upstreamPort = "9000";
      webSockets = true;
    }
  ];
  services.authentik = {
    enable = true;
    environmentFile = config.sops.secrets.authentik_env.path;
    settings = {
      # Keep packaged blueprint paths and the existing Forgejo instance stable.
      blueprints_dir =
        pkgs.runCommand "authentik-nas-blueprints" { } ''
          mkdir -p "$out"
          cp -rL --no-preserve=mode ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints/. "$out/"
          mkdir -p "$out/nas"
          cp ${../../hosted-services/forgejo/blueprint.yaml} "$out/nas/forgejo.yaml"
          cp ${./beau.yaml} "$out/nas/beau.yaml"
        ''
        |> toString;
      disable_startup_analytics = true;
      avatars = "attributes.avatar,gravatar,initials";
    };
  };
  systemd.services.authentik-worker.serviceConfig.LoadCredential = [
    "beau-email:${config.sops.secrets."authentik/users/beau/email".path}"
    "beau-initial-password:${config.sops.secrets."authentik/users/beau/initial-password".path}"
  ];
  sops.secrets."authentik/users/beau/email" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [ "authentik-worker.service" ];
  };
  sops.secrets."authentik/users/beau/initial-password" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [ "authentik-worker.service" ];
  };
  sops.secrets.authentik_env = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
  };
}
