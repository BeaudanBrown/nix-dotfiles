{
  config,
  inputs,
  lib,
  ...
}:
let
  domain = "invoice.bepis.lol";
  erpDomain = "erp.bepis.lol";
  portKey = "invoice-ai";
  erpPortKey = "invoice-ai-erpnext";
  serviceUser = "invoice-ai";
  serviceGroup = "invoice-ai";
in
{
  imports = [ inputs.invoice-ai.nixosModules.default ];

  custom.ports.requests = [
    { key = portKey; }
    { key = erpPortKey; }
  ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
    {
      domain = erpDomain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${erpPortKey};
      webSockets = true;
    }
  ];

  sops.secrets = {
    "invoice-ai/env" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
      restartUnits = [ "invoice-ai.service" ];
    };

    "invoice-ai/operator-tokens" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
      restartUnits = [ "invoice-ai.service" ];
    };

    "invoice-ai/erpnext-credentials" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
      restartUnits = [ "invoice-ai.service" ];
    };

    "invoice-ai/erpnext-db-root-password" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [
        "invoice-ai-erpnext-secrets.service"
        "podman-erpnext-db.service"
        "invoice-ai-erpnext-create-site.service"
      ];
    };

    "invoice-ai/erpnext-db-password" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "invoice-ai-erpnext-create-site.service" ];
    };

    "invoice-ai/erpnext-admin-password" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "invoice-ai-erpnext-create-site.service" ];
    };

    "invoice-ai/erpnext-frappe-secret-key" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "invoice-ai-erpnext-apply-site-config.service" ];
    };
  };

  services.invoice-ai = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    publicUrl = "https://${domain}";
    hostName = domain;
    environmentFile = config.sops.secrets."invoice-ai/env".path;

    operatorAuth.tokensFile = config.sops.secrets."invoice-ai/operator-tokens".path;

    erpnext = {
      mode = "embedded";
      credentialsFile = config.sops.secrets."invoice-ai/erpnext-credentials".path;
      publicUrl = "https://${erpDomain}";
      siteName = erpDomain;
      siteHost = erpDomain;
      frontendPort = config.custom.ports.assigned.${erpPortKey};
      secrets = {
        dbRootPasswordFile = config.sops.secrets."invoice-ai/erpnext-db-root-password".path;
        dbPasswordFile = config.sops.secrets."invoice-ai/erpnext-db-password".path;
        adminPasswordFile = config.sops.secrets."invoice-ai/erpnext-admin-password".path;
        frappeSecretKeyFile = config.sops.secrets."invoice-ai/erpnext-frappe-secret-key".path;
      };
    };

    docling.url =
      if config.services.docling-serve.enable then
        "http://${config.services.docling-serve.host}:${toString config.services.docling-serve.port}"
      else
        null;
  };

  systemd.services.invoice-ai = {
    after = lib.optionals config.services.docling-serve.enable [ "docling-serve.service" ];
    wants = lib.optionals config.services.docling-serve.enable [ "docling-serve.service" ];
    serviceConfig = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      UMask = "0077";
    };
  };
}
