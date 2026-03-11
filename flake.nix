{
  outputs =
    {
      self,
      nixpkgs,
      nixpkgsUnstable,
      flake-utils,
      ...
    }@inputs:
    # TODO: Somewhere there is a sops thing making .config
    let
      inherit (self) outputs;
      # ========== Extend lib with lib.custom ==========
      # NOTE: This approach allows lib.custom to propagate into hm
      # see: https://github.com/nix-community/home-manager/pull/3454
      lib = nixpkgs.lib.extend (
        self: super: {
          custom = import ./lib {
            inherit (nixpkgs) lib;
            inherit inputs;
          };
        }
      );
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
        packages = {
          generate-host-imports = pkgs.callPackage ./scripts/generate-host-imports.nix { };
        };
        checks = import ./lib/checks.nix { inherit inputs system pkgs; };
        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
        };
      }
    )
    // {
      nixosConfigurations =
        builtins.readDir ./hosts
        |> builtins.attrNames
        |> map (host: {
          name = host;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit
                inputs
                outputs
                lib
                host
                nixpkgsUnstable
                ;
            };
            modules = [ ./hosts/${host} ];
          };
        })
        |> builtins.listToAttrs;
    };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sopsSecrets = {
      url = "git+ssh://git@github.com/BeaudanBrown/sops-secrets.git?shallow=1";
      flake = false;
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    systems.url = "github:nix-systems/default";

    flake-utils.url = "github:numtide/flake-utils";

    nix-ai-tools = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    copyparty = {
      url = "github:9001/copyparty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    joan-flash = {
      url = "github:BeaudanBrown/joan-tracker";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    loom = {
      url = "github:ghuntley/loom";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    complix.url = "github:BeaudanBrown/complix";

    openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };
  };
}
