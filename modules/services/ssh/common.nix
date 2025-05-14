{ config, ... }:
{
  sops.secrets = {
    "ssh/${config.networking.hostName}/priv" = {
      path = "${config.hostSpec.home}/.ssh/id_ed25519";
      mode = "0600";
      owner = config.hostSpec.username;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
}
