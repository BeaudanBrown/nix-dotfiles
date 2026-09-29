{
  config,
  lib,
  pkgs,
  ...
}:
{
  sops.secrets."pi/matrix-nas-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
    # Only: PI_MATRIX_ACCESS_TOKEN=<token for @pi-nas:matrix.bepis.lol>
    # Separate identity from the existing NAS owner-account chat assistant.
  };

  # Like GRILL, these managed sessions share the trusted user's tmux server.
  systemd.user.services.pi-managed-session-relay.serviceConfig.NoNewPrivileges = lib.mkForce false;
  services.pi-harness.managedSessions = {
    enable = true;
    user = config.hostSpec.username;
    environmentFile = config.sops.secrets."pi/matrix-nas-env".path;
    homeserver = "https://matrix.bepis.lol";
    botUserId = "@pi-nas:matrix.bepis.lol";
    operatorUserId = "@beau:matrix.bepis.lol";
    ignoredSenderUserIds = [
      "@whatsappbot:matrix.bepis.lol"
      "@signalbot:matrix.bepis.lol"
      "@facebookbot:matrix.bepis.lol"
    ];
    hostId = "nas";
    workspaceRoots.projects = "${config.hostSpec.home}/documents/projects";
    launcherPackage = import ../tmux/tmux_project.nix { inherit pkgs; };
  };
}
