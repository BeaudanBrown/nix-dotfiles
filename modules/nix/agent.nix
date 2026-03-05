{ config, ... }:
{
  nix = {
    settings = {
      builders-use-substitutes = true;
    };

    buildMachines = [
      {
        hostName = "nas";
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        sshUser = "beau";
        sshKey = config.sops.secrets."ssh/${config.networking.hostName}/priv".path;
        protocol = "ssh-ng";
        maxJobs = 8;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
      }
    ];

    distributedBuilds = true;
  };
}
