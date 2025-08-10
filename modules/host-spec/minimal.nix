# Specifications For Differentiating Hosts
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.hostSpec = {
    # Data variables that don't dictate configuration settings
    username = lib.mkOption {
      type = lib.types.str;
      description = "The username of the host";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the host";
    };
    tailIP = lib.mkOption {
      type = lib.types.str;
      description = "Headscale ip address";
    };
    tailDomain = lib.mkOption {
      type = lib.types.str;
      description = "The tailscale server domain";
      default = "nas.lan";
    };
    sshPort = lib.mkOption {
      type = lib.types.int;
      description = "The port to run sshd service on";
      default = 22;
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "The email of the user";
    };
    wifi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate if a host has wifi";
    };
    dotfiles = lib.mkOption {
      type = lib.types.str;
      description = "The location of the host dotfiles";
      default = "${config.hostSpec.home}/documents/nix-dotfiles";
    };
    userFullName = lib.mkOption {
      type = lib.types.str;
      description = "The full name of the user";
    };
    home = lib.mkOption {
      type = lib.types.str;
      description = "The home directory of the user";
      default =
        let
          user = config.hostSpec.username;
        in
        if pkgs.stdenv.isLinux then "/home/${user}" else "/Users/${user}";
    };

    # Configuration Settings
    isBootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Used to indicate a bootstop config";
    };
  };

  options.hm = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Shortcut to home-manager config";
  };

  config.home-manager.users.${config.hostSpec.username} = config.hm;
}
