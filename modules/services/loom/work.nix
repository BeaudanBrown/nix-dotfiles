{ inputs, pkgsUnstable, ... }:
let
  pkgsLoom = pkgsUnstable.extend (import "${inputs.loom}/infra/pkgs" { });
in
{
  environment.systemPackages = [
    pkgsLoom.loom-cli
  ];
}
