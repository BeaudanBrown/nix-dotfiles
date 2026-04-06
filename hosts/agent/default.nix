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
    inputs."pi-harness".nixosModules.pi-harness
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
  ]
  ++ (import ../../generated/imports/agent.nix);

  nix.settings.cores = 6;

  fileSystems."/home/beau/host" = {
    device = "host-agent";
    fsType = "virtiofs";
  };

  thisHost = host;

  system.stateVersion = "25.11";
}
