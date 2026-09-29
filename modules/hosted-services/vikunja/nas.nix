{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "todo.bepis.lol";
  portKey = "vikunja";
in
{
  imports = [ ./agent-host.nix ];

  custom.ports.requests = [ { key = portKey; } ];
  hostedServices = [
    {
      inherit domain;
      tailnet = true;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
    }
  ];

  services.vikunja = {
    enable = true;
    package = pkgs.unstable.vikunja;
    address = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    frontendScheme = "https";
    frontendHostname = domain;
    database.type = "sqlite";
    environmentFiles = [ config.sops.secrets."vikunja/service-env".path ];
    settings = {
      service = {
        timezone = config.time.timeZone;
        enableregistration = false;
        enablelinksharing = false;
        enablecaldav = false;
        enableemailreminders = false;
      };
      mailer.enabled = false;
      webhooks.enabled = false;
      defaultsettings = {
        email_reminders_enabled = false;
        overdue_tasks_reminders_enabled = false;
      };
    };
  };

  sops.secrets."vikunja/service-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "root";
    mode = "0400";
    restartUnits = [ "vikunja.service" ];
    # VIKUNJA_SERVICE_SECRET=<random stable 64-character hex value>
  };
  sops.secrets."vikunja/api-token" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Raw API token belonging to beau; no separate Vikunja agent account needed.
  };
}
