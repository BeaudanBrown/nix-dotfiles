{ outputs, pkgs, ... }:
{
  environment.systemPackages = [
    outputs.packages.${pkgs.system}.ticket
  ];
}
