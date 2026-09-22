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

  # Managed windows share the operator's tmux server and Unix-user authority.
  # If the boot relay starts that server with NNP, every subsequent interactive
  # shell inherits it and sudo breaks. If the operator starts it first, NNP on
  # the relay does not constrain tmux-created processes anyway. This is not an
  # isolation seam; isolated agents would need a separate user/server instead.
  # Override the pinned upstream default only for this shared-session relay.
  systemd.user.services.pi-managed-session-relay.serviceConfig.NoNewPrivileges = lib.mkForce false;

  services.pi-harness.managedSessions = {
    enable = true;
    user = config.hostSpec.username;
    environmentFile = config.sops.secrets."pi/matrix-grill-env".path;
    homeserver = "https://matrix.bepis.lol";
    botUserId = "@pi-grill:matrix.bepis.lol";
    operatorUserId = "@beau:matrix.bepis.lol";
    ignoredSenderUserIds = [
      "@whatsappbot:matrix.bepis.lol"
      "@signalbot:matrix.bepis.lol"
      "@facebookbot:matrix.bepis.lol"
    ];
    hostId = "grill";
    workspaceRoots = {
      projects = workspaceRoot;
      documents = "${config.hostSpec.home}/documents";
    };
    launcherPackage = managedSessionLauncher;
  };
}
