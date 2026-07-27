{
  inputs,
  pkgs,
  ...
}:
let
  fleetInstaller = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.fleet-installer;
  rekeyCommand = pkgs.writeShellApplication {
    name = "installer-sops-rekey";
    runtimeInputs = with pkgs; [
      fleetInstaller
      git
      util-linux
      sops
    ];
    text = ''
      exec fleet-installer nas-rekey
    '';
  };
in
{
  environment.systemPackages = [ rekeyCommand ];
}
