{
  config,
  lib,
  pkgs,
  ...
}:
let
  windowLauncher = import ../tmux/tmux_project.nix { inherit pkgs; };
in
{
  imports = [ ./native-retention.nix ];

  sops.secrets."pi/matrix-nas-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Only PI_MATRIX_ACCESS_TOKEN=<token for @pi-nas:matrix.bepis.lol>.
    # Separate from the owner-account helper/stateless !pi service.
  };

  # Normal native startup after completed migration; native Pi and tmux remain
  # independent. Retained account state is neither reimported nor cleaned up.
  services.pi-harness.matrixBridge = {
    enable = true;
    user = config.hostSpec.username;
    environmentFile = config.sops.secrets."pi/matrix-nas-env".path;
    homeserver = "https://matrix.bepis.lol";
    botUserId = "@pi-nas:matrix.bepis.lol";
    operatorUserId = "@beau:matrix.bepis.lol";
    retainRuntime = true;
    ignoredSenderUserIds = [
      "@whatsappbot:matrix.bepis.lol"
      "@signalbot:matrix.bepis.lol"
      "@facebookbot:matrix.bepis.lol"
    ];
    hostId = "nas";
    projectRoot = "${config.hostSpec.home}/documents/projects";
    roots = [ "${config.hostSpec.home}/documents/projects" ];
    sessionRoots = [
      "%h/.pi/agent/sessions"
      "%h/.local/state/pi-managed-sessions/project-sessions"
    ];
    tmuxPackage = pkgs.tmux;
    inherit windowLauncher;
  };
}
