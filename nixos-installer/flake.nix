{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
  };

  outputs =
    {
    self,
    nixpkgs,
    ...
    }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib.extend (self: super: { custom = import ../lib { inherit (nixpkgs) lib; }; });

      minimalSpecialArgs = {
        inherit inputs outputs lib;
      };

      # This mkHost is way better: https://github.com/linyinfeng/dotfiles/blob/8785bdb188504cfda3daae9c3f70a6935e35c4df/flake/hosts.nix#L358
      newConfig =
        host: user:
        (
          let
            spec = {
              username = user;
              hostName = host;
              email = "beaudan.brown@gmail.com";
              wifi = true;
              userFullName = "Beaudan Brown";
              sshPort = 22;
            };
          in
            lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = minimalSpecialArgs;
              modules = [
                inputs.disko.nixosModules.disko
                inputs.home-manager.nixosModules.home-manager
                (lib.custom.relativeToRoot "modules/common/system/disko/${host}.nix")
                (lib.custom.relativeToRoot "hosts/${host}/hardware.nix")
                {
                  hostSpec = spec;

                  # TODO: Figure out if password and boot loader can be moved somewhere
                  users.users.${spec.username} = {
                    hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
                  };
                  boot.loader = {
                    timeout = 1;
                    efi.canTouchEfiVariables = true;
                    systemd-boot.enable = false;
                    grub = {
                      enable = true;
                      efiSupport = true;
                      device = "nodev";
                      configurationLimit = 10;
                    };
                  };
                }
              ] ++ (lib.custom.importAll {
                  inherit host spec;
                  roots = [ "minimal" ];
                });
            }
        );
    in
      {
      nixosConfigurations = {
        # host = newConfig "hostname" username"
        grill = newConfig "grill" "beau";
      };
    };
}
