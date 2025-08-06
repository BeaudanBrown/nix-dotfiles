{ config, lib, ... }:
{
  services.nginx.virtualHosts."docs.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.collabora-online.port}";
      proxyWebsockets = true;
    };
  };
  services.collabora-online = {
    enable = true;
    settings = {
      server_name = "docs.bepis.lol";
      ssl = {
        enable = false;
        termination = true;
      };

      net = {
        listen = "127.0.0.1";
        post_allow.host = [ "0.0.0.0" ];
      };

      storage.wopi = {
        "@allow" = true;
        host = [ config.services.nextcloud.hostName ];
      };
    };
  };

  # TODO: Ensure this only enabled if nextcloud is
  systemd.services.nextcloud-config-collabora =
    let
      inherit (config.services.nextcloud) occ;
      wopi_url = "http://127.0.0.1:${toString config.services.collabora-online.port}";
      public_wopi_url = "https://docs.bepis.lol";
      wopi_allowlist = lib.concatStringsSep "," [
        "127.0.0.1"
        "::1"
      ];
    in
    {
      wantedBy = [ "multi-user.target" ];
      after = [
        "nextcloud-setup.service"
        "coolwsd.service"
      ];
      requires = [ "coolwsd.service" ];
      script = ''
        ${occ}/bin/nextcloud-occ config:app:set richdocuments wopi_url --value ${lib.escapeShellArg wopi_url}
        ${occ}/bin/nextcloud-occ config:app:set richdocuments public_wopi_url --value ${lib.escapeShellArg public_wopi_url}
        ${occ}/bin/nextcloud-occ config:app:set richdocuments wopi_allowlist --value ${lib.escapeShellArg wopi_allowlist}
        ${occ}/bin/nextcloud-occ richdocuments:setup
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

  # Need this when behind NAT because the wopi_allowlist needs an IP
  # https://diogotc.com/blog/collabora-nextcloud-nixos/
  networking.hosts = {
    "127.0.0.1" = [
      "cloud.bepis.lol"
      "docs.bepis.lol"
    ];
    "::1" = [
      "cloud.bepis.lol"
      "docs.bepis.lol"
    ];
  };
}
