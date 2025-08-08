{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
              # TODO: make this configurable?
              wifi = true;
              userFullName = "Beaudan Brown";
              sshPort = 22;
              isBootstrap = true;
            };
          in
          lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = minimalSpecialArgs;
            modules = [
              inputs.disko.nixosModules.disko
              inputs.home-manager.nixosModules.home-manager
              inputs.sops-nix.nixosModules.sops
              (lib.custom.relativeToRoot "modules/system/disko/${host}.nix")
              (lib.custom.relativeToRoot "hosts/${host}/hardware.nix")
              {
                hostSpec = spec;
              }
            ]
            ++ (lib.custom.importAll {
              inherit host;
              roots = [ "minimal" ];
            });
          }
        );
    in
    {
      nixosConfigurations = {
        # host = newConfig "hostname" username"
        grill = newConfig "grill" "beau";
        laptop = newConfig "laptop" "beau";
        nas = newConfig "nas" "beau";
      };
    };
}
