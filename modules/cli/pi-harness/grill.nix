{
  config,
  lib,
  pkgs,
  ...
}:
let
  workspaceRoot = "${config.hostSpec.home}/documents/projects";
  managedSessionLauncher = import ../tmux/tmux_project.nix { inherit pkgs; };
in
{
  sops.secrets."pi/matrix-grill-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Populate as an env file containing only:
    # PI_MATRIX_ACCESS_TOKEN=<token for @pi-grill:matrix.bepis.lol>
  };

  services.pi-harness.managedSessions = {
    enable = true;
    user = config.hostSpec.username;
    environmentFile = config.sops.secrets."pi/matrix-grill-env".path;
    homeserver = "https://matrix.bepis.lol";
    botUserId = "@pi-grill:matrix.bepis.lol";
    operatorUserId = "@beau:matrix.bepis.lol";
    ignoredSenderUserIds = [
      "@signalbot:matrix.bepis.lol"
      "@facebookbot:matrix.bepis.lol"
    ];
    hostId = "grill";
    workspaceRoots.projects = workspaceRoot;
    launcherPackage = managedSessionLauncher;
  };
}
