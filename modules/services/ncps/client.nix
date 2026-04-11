{ ... }:

{
  nix = {
    settings = {
      substituters = [
        "https://cache.bepis.lol"
      ];
      trusted-public-keys = [
        "cache.bepis.lol-1:RICGW/iQ761PR6QiMUwbOLcvKird8EHoDd/ylnDOGJY="
      ];
      builders-use-substitutes = true;
    };

    buildMachines = [
      {
        hostName = "nas";
        # TODO: Cross compilation?
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        sshUser = "beau";
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
