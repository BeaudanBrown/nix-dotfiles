{
  lib,
  pkgs,
  config,
  ...
}:
{
  environment = {
    systemPackages = [ pkgs.sops ];
  };
  sops = {
    defaultSopsFile = lib.custom.relativeToRoot "secrets.yaml";
    validateSopsFiles = false;
    age = {
      # Key to use to derive age key
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      # Where to store age key
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    # Which secrets to use, get stored by default in /run/secrets/<name>
    secrets = {
      "ssh/${config.networking.hostName}/priv" = {
        path = "/home/${config.hostSpec.username}/.ssh/id_ed25519";
        mode = "0600";
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
      };
    };
  };
}
