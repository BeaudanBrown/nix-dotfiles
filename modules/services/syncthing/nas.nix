{
  config,
  lib,
  ...
}:
{
  hostedServices = [
    {
      domain = "sync.bepis.lol";
      tailnet = true;
      upstreamPort = "8384";
    }
  ];

  services.syncthing = {
    settings = {
      gui.insecureSkipHostcheck = true;
      devices = {
        "reuben" = {
          id = "YKK6IIA-4KIDKID-UIJ7WF7-ZVFHMAE-4YSXXRG-M434Y46-537RI3E-U2MSDQE";
        };
      };
      folders = {
        documents.path = lib.mkForce "${config.hostSpec.home}/documents";
        monash.path = lib.mkForce "${config.hostSpec.home}/monash";
        collab.path = lib.mkForce "${config.hostSpec.home}/collab";
      };
    };
  };
}
