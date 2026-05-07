{
  inputs,
  host,
  nixpkgsUnstable,
  ...
}:
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.default
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
    "${inputs.nixpkgs}/nixos/modules/profiles/minimal.nix"
    ./oneplus-fajita/system.nix
  ];

  thisHost = host;

  nixpkgs.overlays = [
    (final: prev: {
      unstable = import nixpkgsUnstable {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    })
  ];

  system.stateVersion = "25.11";
}
