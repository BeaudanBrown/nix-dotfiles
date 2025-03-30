{
  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;
      # ========== Extend lib with lib.custom ==========
      # NOTE: This approach allows lib.custom to propagate into hm
      # see: https://github.com/nix-community/home-manager/pull/3454
      lib = nixpkgs.lib.extend (self: super: { custom = import ./lib { inherit (nixpkgs) lib; }; });
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map (host: {
          name = host;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs outputs lib;
            };
            modules = [ ./hosts/${host} ];
          };
        }) (builtins.attrNames (builtins.readDir ./hosts))
      );
    };
    # let
    #   inherit (nixpkgs) lib;
    #   configLib = import ./lib { inherit lib; };
    #   specialArgs = {
    #     inherit
    #     inputs
    #     configLib
    #     nixpkgs
    #     ;
    #   };
    # in
    # {


    # nixpkgs.overlays = [
    # ];

    # nixosConfigurations = {
    #   grill = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     inherit specialArgs;
    #     modules = [
    #       ./nixos/grill

    #       nixvim.nixosModules.nixvim
    #       stylix.nixosModules.stylix
    #       home-manager.nixosModules.home-manager
    #       {
    #         home-manager.useGlobalPkgs = true;
    #         home-manager.useUserPackages = true;
    #         home-manager.backupFileExtension = "backup";
    #         home-manager.users.beau = import ./home/grill;
    #         home-manager.extraSpecialArgs = specialArgs;
    #       }
    #     ];
    #   };

    #   nix-laptop = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     inherit specialArgs;
    #     modules = [
    #       ./nixos/laptop

    #       nixvim.nixosModules.nixvim
    #       stylix.nixosModules.stylix
    #       home-manager.nixosModules.home-manager
    #       {
    #         home-manager.useGlobalPkgs = true;
    #         home-manager.useUserPackages = true;
    #         home-manager.backupFileExtension = "backup";
    #         home-manager.users.beau = import ./home/laptop;
    #         home-manager.extraSpecialArgs = specialArgs;
    #       }
    #     ];
    #   };
    # };
  # };
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.config.allowUnfree = true;

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim.url = "github:nix-community/nixvim";

    stylix.url = "github:danth/stylix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
