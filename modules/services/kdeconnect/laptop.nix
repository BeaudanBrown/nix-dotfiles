{ config, ... }:
{
  sops.secrets = {
    "kdeconnect/${config.networking.hostName}" = {
      path = "${config.hostSpec.home}/.config/kdeconnect/trusted_devices";
      mode = "0644";
      owner = config.hostSpec.username;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
}
