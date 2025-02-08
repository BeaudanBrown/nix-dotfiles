{
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

  outputs = { nixpkgs, ... }@inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          meta = {
            name = "dotfiles";
            title = "Dotfiles";
          };

          namespace = "dotfiles";
        };
      };
    in
    lib.mkFlake
    {
      channels-config = {
        allowUnfree = true;
      };

      systems.modules.nixos = with inputs; [
        nixvim.nixosModules.nixvim
        stylix.nixosModules.stylix
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
      ];
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
}
