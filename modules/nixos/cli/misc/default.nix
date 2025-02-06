{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.misc;
in {

  options.${namespace}.cli.misc = {
    enable = mkBoolOpt false "Whether or not to enable common utilities.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jq
      htop
      ripgrep
      unzip
      gnumake
    ];
    environment.shellAliases = import ./aliases.nix { inherit pkgs; };
  };
}
