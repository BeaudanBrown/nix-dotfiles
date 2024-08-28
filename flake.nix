{
	nixConfig = {
		extra-substituters = [
			"https://nix-community.cachix.org/"
			"https://hyprland.cachix.org"
		];
		extra-trusted-public-keys = [
			"nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
			"hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
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
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hyprland, home-manager, nixvim, stylix, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      configLib = import ./lib { inherit lib; };
      specialArgs = {
        inherit
        inputs
        hyprland
        configLib
        nixpkgs
        ;
      };
    in
    {

    nixpkgs.overlays = [
    ];

    nixosConfigurations = {
      grill = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = [
          ./hosts/grill
          nixvim.nixosModules.nixvim
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.beau = import ./home.nix;
            home-manager.extraSpecialArgs = specialArgs;
          }
        ];
      };

      nix-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          nixvim.nixosModules.nixvim
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.beau = import ./home.nix;
          }
        ];
      };
    };

  };
}
