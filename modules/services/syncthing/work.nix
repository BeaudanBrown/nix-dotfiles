{
  config,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.config/syncthing 0700 ${config.hostSpec.username} users - -"
  ];
  users.users.${config.hostSpec.username}.extraGroups = [ "syncthing" ];
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = config.hostSpec.username;
    dataDir = "${config.hostSpec.home}";
    settings = {
      options = {
        urAccepted = -1;
      };
      devices = {
        "server" = {
          id = "YZLDZHW-7MYKYEM-5PTTWLU-TBPEQJX-CJEFVBS-UYIOQJM-OKCQ723-25HTDAT";
          autoAcceptFolder = true;
        };
        "laptop" = {
          id = "T2YY6AY-XQNZQQW-RRI52RN-EARJZHR-6GPNA2A-2QBRMFD-TOHY5SH-MXFKVAC";
          autoAcceptFolder = true;
        };
        "grill" = {
          id = "B4SXNGB-I6QC6RM-GCPSPXR-JSCTBNJ-RTFDNVW-OPVO3TB-BQ7EDSO-ODJV4AC";
          autoAcceptFolder = true;
        };
      };
      folders = {
        "documents" = {
          id = "txxit-w9cwz";
          path = "~/documents";
          devices = [
            "server"
            "grill"
            "laptop"
          ];
        };
        "monash" = {
          id = "twjfr-ekoqc";
          path = "~/monash";
          devices = [
            "server"
            "grill"
            "laptop"
          ];
        };
        "collab" = {
          id = "vccfp-s5yfe";
          path = "~/collab";
          devices = [
            "server"
            "grill"
            "laptop"
          ];
        };
      };
    };
  };
  sops.secrets."syncthing/${config.networking.hostName}/cert" = {
    path = "${config.hostSpec.home}/.config/syncthing/cert.pem";
    mode = "0400";
    owner = config.hostSpec.username;
    group = "users";
    restartUnits = [ "syncthing.service" ];
  };

  sops.secrets."syncthing/${config.networking.hostName}/key" = {
    path = "${config.hostSpec.home}/.config/syncthing/key.pem";
    mode = "0400";
    owner = config.hostSpec.username;
    group = "users";
    restartUnits = [ "syncthing.service" ];
  };
}
