# Specifications For Differentiating Hosts
{
  config,
  pkgs,
  lib,
  ...
}:
let
  hostSpecType = lib.types.submodule {
    options = {
      hostName = lib.mkOption {
        type = lib.types.str;
        description = "The hostname of the host";
      };
      username = lib.mkOption {
        type = lib.types.str;
        description = "The username of the host";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "The email of the user";
      };
      userFullName = lib.mkOption {
        type = lib.types.str;
        description = "The full name of the user";
      };
      tailIP = lib.mkOption {
        type = lib.types.str;
        description = "Headscale ip address";
        default = "";
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
      home = lib.mkOption {
        type = lib.types.str;
        description = "The home directory of the user";
        default =
          let
            user = config.hostSpec.username;
          in
          if pkgs.stdenv.isLinux then "/home/${user}" else "/Users/${user}";
      };
      isBootstrap = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Used to indicate a bootstrap config";
      };
      roots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "The list of roots (environment categories) this host belongs to";
      };
      ageHostKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The age public key derived from the host's SSH key";
      };
      ageUserKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The age public key for the user (format: username_hostname)";
      };
    };
  };

  allHostsData = import ./all-hosts.nix;
in
{
  options.hostSpecs = lib.mkOption {
    type = lib.types.attrsOf hostSpecType;
    description = "Specifications for all hosts in the fleet";
    default = allHostsData.hostSpecs;
  };

  options.thisHost = lib.mkOption {
    type = lib.types.str;
    description = "The hostname of this host (must match a key in hostSpecs)";
  };

  options.hostSpec = lib.mkOption {
    type = hostSpecType;
    description = "Convenience alias for the current host's specification";
  };

  options.hm = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Shortcut to home-manager config";
  };

  config = {
    # Create the convenience alias pointing to this host's spec
    hostSpec = config.hostSpecs.${config.thisHost};

    # Home manager integration
    home-manager.users.${config.hostSpec.username} = config.hm;
  };
}
