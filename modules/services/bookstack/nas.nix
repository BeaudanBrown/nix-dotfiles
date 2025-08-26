{
  config,
  pkgs,
  ...
}:
let
  domain = "notes.bepis.lol";
  portKey = "bookstack";
in
{
  custom.ports.requests = [ { key = portKey; } ];
  sops.secrets.bookstack = {
    path = "${config.services.bookstack.dataDir}/bookstack_key";
    mode = "0600";
    owner = config.services.bookstack.user;
    group = config.services.bookstack.group;
  };
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "bookstack" ];
    ensureUsers = [
      {
        name = "bookstack";
        ensurePermissions = {
          "bookstack.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };
  systemd.services."bookstack-setup" = {
    after = [
      "mysql.service"
      "mariadb.service"
    ];
    wants = [ "mysql.service" ];
  };
  services.bookstack = {
    enable = true;
    hostname = "bookstack.internal";
    settings = {
      APP_ENV = "production";
      APP_URL = "https://${domain}";
      APP_KEY_FILE = config.sops.secrets.bookstack.path;

      DB_CONNECTION = "mysql";
      DB_HOST = "localhost";
      DB_DATABASE = "bookstack";
      DB_USERNAME = "bookstack";
      DB_SOCKET = "/run/mysqld/mysqld.sock";
    };
    nginx.listen = [
      {
        addr = "127.0.0.1";
        port = config.custom.ports.assigned.${portKey};
        ssl = false;
      }
    ];
  };
  hostedServices = [
    {
      domain = domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
    }
  ];
}
