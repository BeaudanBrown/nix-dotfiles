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
  imports = [ ./cutover-172.nix ];
  services.piNativeCutover172 = {
    enable = true;
    startAfterMigration = false; # Separate activation approval after report review.
  };

  sops.secrets."pi/matrix-nas-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Only PI_MATRIX_ACCESS_TOKEN=<token for @pi-nas:matrix.bepis.lol>.
    # Separate from the owner-account helper/stateless !pi service.
  };

  # The temporary cutover job also holds NAS assistant startup. Source changes
  # are not live maintenance approval; native Pi and tmux remain independent.
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
    roots = [ "${config.hostSpec.home}/documents/projects" ];
    sessionRoots = [
      "%h/.pi/agent/sessions"
      "%h/.local/state/pi-managed-sessions/project-sessions"
    ];
    tmuxPackage = pkgs.tmux;
    inherit windowLauncher;
  };
}
