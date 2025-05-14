{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    codex
  ];
  environment.shellAliases = {
    apply_patch = "patch";
  };
}
