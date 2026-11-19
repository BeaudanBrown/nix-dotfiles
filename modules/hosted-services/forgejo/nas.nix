{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "git.bepis.lol";
  key = "forgejo/http";
  port = config.custom.ports.assigned.${key};
  secret = config.sops.secrets."forgejo/oidc-client-secret".path;
  username = config.sops.secrets."forgejo/authentik-username".path;
  cfg = config.services.forgejo;
  ak = config.services.authentik.authentikComponents;
  # The LTS admin auth CLI otherwise requires the client secret in process argv.
  # Add a value source only to the OAuth admin flag, not to the web service.
  adminPackage = pkgs.forgejo-lts.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace cmd/admin_auth_oauth.go --replace-fail 'Name:  "secret",' \
        'Name: "secret", Sources: cli.EnvVars("NAS_FORGEJO_CLIENT_SECRET"),'
    '';
  });
in
{
  custom.ports.requests = [ { inherit key; } ];
  hostedServices = [
    {
      inherit domain;
      tailnet = true;
      upstreamPort = toString port;
      webSockets = true;
    }
  ];

  services.forgejo = {
    enable = true;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = port;
        DISABLE_SSH = true;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = true;
      };
      oauth2_client = {
        ENABLE_AUTO_REGISTRATION = true;
        ACCOUNT_LINKING = "disabled";
        USERNAME = "nickname";
      };
      repository.DEFAULT_PRIVATE = "private";
      session.COOKIE_SECURE = true;
      openid.ENABLE_OPENID_SIGNIN = false;
      openid.ENABLE_OPENID_SIGNUP = false;
    };
  };

  sops.secrets."forgejo/oidc-client-secret" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [
      "authentik-worker.service"
      "forgejo.service"
    ];
  };
  sops.secrets."forgejo/authentik-username" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    restartUnits = [
      "authentik-worker.service"
      "forgejo.service"
    ];
  };

  # Copy the complete tree, following symlinks: authentik discovers YAML by
  # recursive traversal. Preserve relative names for already imported blueprints.
  services.authentik.settings.blueprints_dir =
    pkgs.runCommand "authentik-blueprints-with-forgejo" { } ''
      mkdir -p "$out"
      cp -rL --no-preserve=mode ${ak.staticWorkdirDeps}/blueprints/. "$out/"
      mkdir -p "$out/nas"
      cp ${./blueprint.yaml} "$out/nas/forgejo.yaml"
    ''
    |> toString;
  systemd.services.authentik-worker.serviceConfig.LoadCredential = [
    "forgejo-secret:${secret}"
    "forgejo-username:${username}"
  ];
  systemd.services.forgejo = {
    serviceConfig.LoadCredential = [
      "oidc:${secret}"
      "oidc-username:${username}"
    ];
    # The upstream preStart writes app.ini and migrates the DB first. Bootstrap
    # the local administrator before accepting the first external login.
    preStart = lib.mkAfter ''
      set -euo pipefail
      umask 077
      cli=${lib.getExe cfg.package}
      admins=$("$cli" admin user list --admin)
      if ! ${pkgs.gawk}/bin/awk '$2 == "forgejo-recovery" && $4 == "true" {ok=1} END {exit !ok}' <<< "$admins"; then
        receipt=$(mktemp "${cfg.stateDir}/.recovery.XXXXXX")
        "$cli" admin user create --username forgejo-recovery --email recovery@forgejo.invalid \
          --admin --random-password --random-password-length 40 --must-change-password > "$receipt"
        mv -T "$receipt" "${cfg.stateDir}/initial-recovery-login"
      fi

      sources=$("$cli" admin auth list)
      id=$(${pkgs.gawk}/bin/awk '$2 == "authentik" {if (seen++ || $3 != "OAuth2" || $1 !~ /^[0-9]+$/) exit 1; print $1}' <<< "$sources")
      command=(add-oauth)
      if [[ -n "$id" ]]; then command=(update-oauth --id "$id"); fi
      user=$(<"$CREDENTIALS_DIRECTORY/oidc-username")
      NAS_FORGEJO_CLIENT_SECRET=$(<"$CREDENTIALS_DIRECTORY/oidc")
      test -n "$user" && test -n "$NAS_FORGEJO_CLIENT_SECRET" || exit 1
      export NAS_FORGEJO_CLIENT_SECRET
      ${lib.getExe adminPackage} admin auth "''${command[@]}" --name authentik \
        --provider openidConnect --key nas-forgejo \
        --auto-discover-url https://auth.bepis.lol/application/o/forgejo/.well-known/openid-configuration \
        --scopes openid --scopes profile --scopes email \
        --required-claim-name preferred_username --required-claim-value "$user"
    '';
  };
}
