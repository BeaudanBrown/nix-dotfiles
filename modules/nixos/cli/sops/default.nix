{
  lib,
  pkgs,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.sops;
in
{
  options.${namespace}.cli.sops = {
    enable = mkBoolOpt false "Whether to enable sops configuration.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.sops ];
    };
    sops = {
      defaultSopsFile = relativeToRoot "secrets.yaml";
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
        litellm_api = {
          path = "/home/${config.${namespace}.user.name}/.config/openai.token";
          owner = config.dotfiles.user.name;
          inherit (config.users.users.${config.dotfiles.user.name}) group;
        };
        "ssh/${config.networking.hostName}/priv" = {
          path = "/home/${config.${namespace}.user.name}/.ssh/id_ed25519";
          mode = "0600";
          owner = config.dotfiles.user.name;
          inherit (config.users.users.${config.dotfiles.user.name}) group;
        };
      };
    };
  };
}
