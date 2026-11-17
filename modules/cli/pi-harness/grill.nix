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

  sops.secrets."pi/matrix-grill-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Only PI_MATRIX_ACCESS_TOKEN=<token for @pi-grill:matrix.bepis.lol>.
    # The bridge reads a systemd credential; Pi/tmux never inherit this token.
  };

  # Normal native startup: migration is complete. Retention protects old data
  # independently; neither startup nor rebuild launches or replaces native Pi.
  services.pi-harness.matrixBridge = {
    enable = true;
    user = config.hostSpec.username;
    environmentFile = config.sops.secrets."pi/matrix-grill-env".path;
    homeserver = "https://matrix.bepis.lol";
    botUserId = "@pi-grill:matrix.bepis.lol";
    operatorUserId = "@beau:matrix.bepis.lol";
    retainRuntime = true;
    ignoredSenderUserIds = [
      "@whatsappbot:matrix.bepis.lol"
      "@signalbot:matrix.bepis.lol"
      "@facebookbot:matrix.bepis.lol"
    ];
    hostId = "grill";
    projectRoot = "${config.hostSpec.home}/documents/projects";
    roots = [
      "${config.hostSpec.home}/documents/projects"
      "${config.hostSpec.home}/documents"
      "${config.hostSpec.home}/collab"
    ];
    # Keep historical native files discoverable without the bridge database.
    # Archive flags are optional presentation, never local launch admission.
    sessionRoots = [
      "%h/.pi/agent/sessions"
      "%h/.local/state/pi-managed-sessions/project-sessions"
    ];
    tmuxPackage = pkgs.tmux;
    inherit windowLauncher;
  };
}
