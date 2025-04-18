{
  lib,
  pkgs,
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
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # Where to store age key
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };
}
