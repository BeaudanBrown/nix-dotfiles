{
  lib,
  inputs,
  host,
  nixpkgsStable,
  ...
}:
let
  roots = [
    "minimal"
    "common"
    "network" # Tailnet + Kitty etc
    "main" # Main machines: desktop, laptop, server
    "work"
  ];
in
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    extraSpecialArgs = { inherit nixpkgsStable; };
  });

  hostSpec = {
    username = "beau";
    hostName = host;
    tailIP = "100.64.0.1";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
  };

  services.tlp = {
    enable = true;
    settings = {
      # Internal battery (BAT0)
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # External/removable battery (BAT1)
      START_CHARGE_THRESH_BAT1 = 75;
      STOP_CHARGE_THRESH_BAT1 = 80;
    };
  };

  services.fwupd.enable = true;

  system.stateVersion = "25.05";
}
