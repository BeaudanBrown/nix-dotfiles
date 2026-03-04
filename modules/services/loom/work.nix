{ inputs, pkgs, ... }:
let
  pkgsLoom = pkgs.unstable.extend (import "${inputs.loom}/infra/pkgs" { });
in
{
  environment.systemPackages = [
    pkgsLoom.loom-cli
  ];
}
