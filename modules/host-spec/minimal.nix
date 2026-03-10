# Specifications For Differentiating Hosts
# Supports multiple users per host with Home Manager for all users
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Type for individual user specification
  userSpecType = lib.types.submodule (
    { config, ... }:
    {
      options = {
        username = lib.mkOption {
          type = lib.types.str;
          description = "The username of the user";
        };
        email = lib.mkOption {
          type = lib.types.str;
          description = "The email of the user";
        };
        userFullName = lib.mkOption {
          type = lib.types.str;
          description = "The full name of the user";
        };
        ageUserKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "The age public key for the user";
        };
        extraGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional groups for this user";
        };
        uid = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "User ID (null for auto-assignment)";
        };
        home = lib.mkOption {
          type = lib.types.str;
          description = "Home directory for the user";
          default = if pkgs.stdenv.isLinux then "/home/${config.username}" else "/Users/${config.username}";
        };
      };
    }
  );

  # Type for host specification with multiple users
  hostSpecType = lib.types.submodule {
    options = {
      hostName = lib.mkOption {
        type = lib.types.str;
        description = "The hostname of the host";
      };
      users = lib.mkOption {
        type = lib.types.listOf userSpecType;
        description = "List of users for this host (first is primary)";
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
        default = "${config.hostSpec.primaryUser.home}/documents/nix-dotfiles";
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

      # Convenience derived options (computed in config)
      primaryUser = lib.mkOption {
        type = userSpecType;
        description = "The primary user (first in the users list)";
      };
      usernames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of all usernames on this host";
      };

      # Backward compatibility aliases
      username = lib.mkOption {
        type = lib.types.str;
        description = "DEPRECATED: Use primaryUser.username";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "DEPRECATED: Use primaryUser.email";
      };
      userFullName = lib.mkOption {
        type = lib.types.str;
        description = "DEPRECATED: Use primaryUser.userFullName";
      };
      ageUserKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "DEPRECATED: Use primaryUser.ageUserKey";
      };
      home = lib.mkOption {
        type = lib.types.str;
        description = "DEPRECATED: Use primaryUser.home";
      };
    };
  };

  allHostsData = import ./all-hosts.nix;
in
{
  options = {
    hostSpecs = lib.mkOption {
      type = lib.types.attrsOf hostSpecType;
      description = "Specifications for all hosts in the fleet";
      default = allHostsData.hostSpecs;
    };

    thisHost = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of this host (must match a key in hostSpecs)";
    };

    hostSpec = lib.mkOption {
      type = hostSpecType;
      description = "Convenience alias for the current host's specification";
    };

    # Home Manager configuration for all users
    # Special keys:
    #   - hm.all: Configuration shared across all users
    #   - hm.primary: Configuration for the primary user (merged with hm.<primaryUsername>)
    #   - hm.<username>: Per-user configuration
    # Usage:
    #   hm.all.programs.git.enable = true;        # All users get git
    #   hm.beau.programs.git.userEmail = "...";   # Only beau gets this email
    #   hm.primary.programs.zsh.enable = true;    # Primary user gets zsh
    hm = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Home Manager configuration. Use 'all' for shared, 'primary' for primary user, or '<username>' for specific users.";
    };

    hmModules = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
      default = { };
      description = "Extra Home Manager modules. Use 'all' for shared modules, 'primary' for the primary user, or '<username>' for specific users.";
    };
  };

  config =
    let
      thisHostSpec = config.hostSpecs.${config.thisHost};
      usersList = thisHostSpec.users;
      primaryUserData = lib.head usersList;

      # Build the hostSpec with computed fields
      computedHostSpec = thisHostSpec // {
        primaryUser = primaryUserData;
        usernames = map (u: u.username) usersList;
        # Convenience aliases for primary user
        username = primaryUserData.username;
        email = primaryUserData.email;
        userFullName = primaryUserData.userFullName;
        ageUserKey = primaryUserData.ageUserKey;
        home = primaryUserData.home;
      };

      # Primary user name
      primaryUsername = computedHostSpec.primaryUser.username;

      # Get per-user HM configs/modules (excluding 'all' and 'primary' keys)
      perUserHmConfigs = lib.filterAttrs (n: v: n != "all" && n != "primary") config.hm;
      perUserHmModules = lib.filterAttrs (n: v: n != "all" && n != "primary") config.hmModules;

      # Build home-manager.users configuration
      # Each user gets their specific config merged with primary config if they're primary
      hmUsersConfig = lib.genAttrs computedHostSpec.usernames (
        username:
        let
          userSpecific = perUserHmConfigs.${username} or { };
          # Primary user also merges hm.primary
          primaryExtra = if username == primaryUsername then config.hm.primary or { } else { };
          userImports =
            (perUserHmModules.${username} or [ ])
            ++ lib.optionals (username == primaryUsername) (config.hmModules.primary or [ ]);
        in
        lib.mkMerge [
          {
            imports = userImports;
          }
          userSpecific
          primaryExtra
        ]
      );
    in
    {
      # Set the convenience alias
      hostSpec = computedHostSpec;

      # Home Manager integration
      home-manager = {
        # Shared modules apply to all users
        sharedModules = [
          inputs.sops-nix.homeManagerModules.sops
          (config.hm.all or { })
          (
            { config, ... }:
            {
              sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
            }
          )
        ]
        ++ (config.hmModules.all or [ ]);

        # Per-user configurations
        users = hmUsersConfig;
      };
    };
}
