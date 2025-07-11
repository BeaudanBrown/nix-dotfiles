{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    just
  ];
}
