# Post-migration protections, independent of the retired one-time importer.
{ config, lib, ... }:
{
  assertions = [
    {
      assertion = builtins.elem config.networking.hostName [ "grill" "nas" ]
        && config.services.pi-harness.matrixBridge.enable
        && config.services.syncthing.enable
        && builtins.hasAttr "state-sync" config.services.syncthing.settings.folders;
      message = "Native retention is restricted to the migrated grill/NAS hosts with state-sync declared.";
    }
  ];

  # Keep frozen capture access/ownership stable; do not remove or re-own backups.
  users.groups.pi-native-cutover-172.members = [ config.hostSpec.username ];
  systemd.user.units = {
    "pi-managed-session-relay.service".enable = false;
    "pi-managed-session-rollout.service".enable = false;
  };
  # Releasing this requires a separate cross-host writer/divergence assessment.
  services.syncthing.settings.folders."state-sync".paused = lib.mkForce true;
  # Retained owner-chat files must not fall back into age-based cleanup.
  systemd.tmpfiles.rules = lib.optional (config.networking.hostName == "nas")
    "x /var/lib/pi-chat-files - - - -";
  # No migration executable, boot receipt, gate, importer, cleanup or Pi launcher.
}
