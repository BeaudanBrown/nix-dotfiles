{ ... }:
let
  DATA_FOLDER = "/pool1/appdata/vaultwarden";
in
{
  services.nginx = {
    virtualHosts = let
      base = locations: {
        inherit locations;

        forceSSL = true;
        enableACME = true;
      };
      proxy = port: base {
        "/".proxyPass = "http://127.0.0.1:" + toString(port) + "/";
      };
    in {
      # Define example.com as reverse-proxied service on 127.0.0.1:3000
      "pw.beaudan.me" = proxy 8222 // { default = true; };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${DATA_FOLDER} 0760 vaultwarden vaultwarden - -"
  ];

  services.vaultwarden = {
    enable = true;
    config = {
      inherit DATA_FOLDER;
      DOMAIN = "https://pw.beaudan.me";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };
  systemd.services.vaultwarden = {
    serviceConfig = {
      ReadWritePaths = [
        DATA_FOLDER
      ];
    };
  };
  sops.secrets = {
    "vaultwarden/rsa_key" = {
      path = "${DATA_FOLDER}/rsa_key.pem";
      mode = "0600";
      owner = "vaultwarden";
      group = "vaultwarden";
    };
  };
}
