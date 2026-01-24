{
  config,
  ...
}:
let
  syncthingFolders = config.services.syncthing.settings.folders;
  generateTmpfilesRules =
    folders:
    builtins.attrNames folders
    |> builtins.concatMap (name: [
      "d /pool1/appdata/syncthing/${name} 0755 ${config.hostSpec.username} users - -"
      "d /pool1/appdata/syncthing/${name}/.stfolder 0744 ${config.hostSpec.username} users - -"
    ]);
in
{
  hostedServices = [
    {
      domain = "sync.bepis.lol";
      tailnet = true;
      upstreamPort = "8384";
    }
  ];

  services.syncthing.settings.gui.insecureSkipHostcheck = true;

  systemd.tmpfiles.rules = [
    "d /pool1/appdata/syncthing 0755 ${config.hostSpec.username} users - -"
  ]
  ++ generateTmpfilesRules syncthingFolders;
}
