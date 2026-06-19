{
  inputs,
  host,
  lib,
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
    inputs."pi-harness".nixosModules.pi-harness
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
    "${inputs.nixpkgs}/nixos/modules/profiles/minimal.nix"
    ./oneplus-fajita/system.nix
  ]
  ++ (import ../../generated/imports/oneplus.nix);

  thisHost = host;

  nixpkgs.overlays = [
    (final: prev: {
      unstable = import nixpkgsUnstable {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };

      hyprlandPlugins = prev.hyprlandPlugins // {
        hyprspace = prev.hyprlandPlugins.hyprspace.overrideAttrs (_old: {
          version = "0-unstable-2026-05-28-local-preview-drag";
          src = inputs.hyprspace-local;
        });
      };
    })
  ];

  nix.settings.cores = 2;

  stylix.fonts.sizes.terminal = lib.mkForce 8;

  system.stateVersion = "25.11";
}
