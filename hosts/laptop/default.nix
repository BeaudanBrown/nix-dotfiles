{
lib,
inputs,
config,
host,
...
}:
let
  modules =
    [
      "common"
      "work"
    ]
    |> builtins.concatMap (
      module:
      let
        path = lib.custom.relativeToRoot "modules/${module}";
      in
        (lib.custom.importAll {
          inherit path;
          spec = config.hostSpec;
          host = host;
        })
    );
in
  {
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.home-manager.nixosModules.home-manager
  ] ++ modules;

  hostSpec = {
    username = "beau";
    hostName = "laptop";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8023;
  };

  system.stateVersion = "23.05";
}
