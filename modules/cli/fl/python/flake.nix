{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      # nixpkgsUnstable,
      flake-utils,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # pkgsUnstable = nixpkgsUnstable.legacyPackages.${system};
      in
      {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              ruff-format.enable = true;
            };
          };
        };
        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInpus = [
            pkgs.bashInteractive
            self.checks.${system}.pre-commit-check.enabledPackages
          ];

          packages = with pkgs; [
            (python3.withPackages (
              python-pkgs: with python-pkgs; [
                # pandas
                # (buildPythonPackage {
                #   pname = "";
                #   version = "";
                #   src = pkgs.fetchFromGitHub {
                #     owner = "akshaynagpal";
                #     repo = "w2n";
                #     rev = "33aac8a1d71ef1dffd4435fe6e9f998154bcb051";
                #     sha256 = "sha256-2hoiTBZdmUmORwVArzZiSWG04jpXcycFaAODtei9Tm4=";
                #   };
                #   src = fetchPypi {
                #     inherit pname version;
                #     sha256 = "";
                #   };
                #   doCheck = false;
                #   checkInputs = [];
                #   propagatedBuildInputs = [];
                #   dependencies = [semantic-version];
                # })
              ]
            ))
          ];
        };
      }
    );
}
