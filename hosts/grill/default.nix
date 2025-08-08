{
  lib,
  inputs,
  config,
  host,
  pkgs,
  ...
}:
let
  roots = [
    "minimal"
    "common"
    "network"
    "work"
    "gaming"
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
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
  });

  nix.settings.cores = 12;
  hardware.bluetooth.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  systemd.tmpfiles.rules =
    let
      rocmEnv = pkgs.symlinkJoin {
        name = "rocm-combined";
        paths = with pkgs.rocmPackages; [
          rocblas
          hipblas
          clr
        ];
      };
    in
    [
      "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
    ];

  users.users.${config.hostSpec.username}.extraGroups = [ "render" ];

  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
  ];

  nixpkgs.config.rocmSupport = true;

  hostSpec = {
    username = "beau";
    hostName = host;
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8022;
  };

  system.stateVersion = "25.05";
}
