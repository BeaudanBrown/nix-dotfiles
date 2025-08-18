{ config, ... }:
let
  domain = "pw.bepis.lol";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.services.vaultwarden.config.ROCKET_PORT;
    }
  ];

  services.vaultwarden = {
    enable = true;
    backupDir = null;
    config = {
      DOMAIN = "https://${domain}";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };
  users.users.${config.hostSpec.username}.extraGroups = [ "vaultwarden" ];

  sops.secrets.vaultwarden = {
    path = "/pool1/appdata/vaultwarden/rsa_key.pem";
    mode = "0600";
    owner = "vaultwarden";
    group = "vaultwarden";
  };
}
