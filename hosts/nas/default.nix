{
  inputs,
  host,
  ...
}:
{
  imports = [
    ./hardware.nix
    ../../modules/scripts/kindle-send/nas.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.disko.nixosModules.disko
    inputs.authentik-nix.nixosModules.default
    inputs.agent-workshop.nixosModules.abrec
    inputs.art-domain.nixosModules.default
    inputs.copyparty.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.joan-flash.nixosModules.default
    inputs.openclaw.nixosModules.openclaw-gateway
    inputs.nix-index-database.nixosModules.default
    inputs."pi-harness".nixosModules.pi-harness
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
  ]
  ++ (import ../../generated/imports/nas.nix);

  # Pause the public proxy without removing its reusable module.
  disabledModules = [ ../../modules/services/tailscale-proxy/nas.nix ];

  # Enable emulation for cross-compilation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  nix.settings.cores = 8;

  thisHost = host;

  system.stateVersion = "25.05";
}
