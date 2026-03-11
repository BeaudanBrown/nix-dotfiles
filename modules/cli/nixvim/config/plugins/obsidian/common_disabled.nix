{ config, ... }:
{
  # Ensure that the default vault exists
  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/documents/vault 0755 ${config.hostSpec.username} users - -"
    "d ${config.hostSpec.home}/documents/vault/main 0755 ${config.hostSpec.username} users - -"
  ];
}
