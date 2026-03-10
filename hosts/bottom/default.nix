{
  inputs,
  host,
  ...
}:
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
    # "${inputs.loom}/infra/nixos-modules/loom-server.nix"
    # "${inputs.loom}/infra/nixos-modules/loom-web.nix"
    # "${inputs.loom}/infra/nixos-modules/k3s.nix"
  ]
  ++ (import ../../generated/imports/bottom.nix);

  nix.settings.cores = 48;

  thisHost = host;

  system.stateVersion = "25.11";
}
