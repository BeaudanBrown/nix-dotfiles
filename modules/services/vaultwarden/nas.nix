{ config, ... }:
{
  # Required to allow systemd service to use custom data folder
  fileSystems."/var/lib/vaultwarden" = {
    device = "/pool1/appdata/vaultwarden";
    options = [ "bind" ];
  };
  systemd.tmpfiles.rules = [
    "d /pool1/appdata/vaultwarden/ 0700 vaultwarden vaultwarden - -"
  ];
  services.nginx.enable = true;
  security.acme = {
    acceptTerms = true;
    defaults.email = "beaudan.brown@gmail.com";
  };
  services.nginx.virtualHosts."pw.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
    };
  };
  services.vaultwarden = {
    enable = true;
    backupDir = null;
    config = {
      DOMAIN = "https://pw.bepis.lol";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };
  users.users.${config.hostSpec.username}.extraGroups = [ "vaultwarden" ];

  sops.secrets.vaultwarden = {
    path = "/pool1/appdata/vaultwarden/rsa_key.pem";
    mode = "0600";
    owner = "vaultwarden";
    group = "vaultwarden";
  };
}
