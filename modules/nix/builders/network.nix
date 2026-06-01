{ config, lib, ... }:
let
  builderSshKey = config.sops.secrets."ssh/${config.networking.hostName}/priv".path;

  allBuildMachines = [
    {
      hostName = "nas";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      sshUser = "beau";
      sshKey = builderSshKey;
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

  buildMachines =
    allBuildMachines |> builtins.filter (builder: builder.hostName != config.hostSpec.hostName);
in
{
  nix = {
    settings = {
      builders-use-substitutes = true;
    };

    inherit buildMachines;
    distributedBuilds = buildMachines != [ ];
  };

  programs.ssh.extraConfig = lib.mkAfter ''
    Host nas
      ConnectTimeout 5
      BatchMode yes
  '';
}
