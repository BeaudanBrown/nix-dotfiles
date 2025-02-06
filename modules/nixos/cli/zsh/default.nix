{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.zsh;
in {
  options.${namespace}.cli.zsh = {
    enable = mkBoolOpt false "Whether to enable zsh configuration.";
  };

  config = mkIf cfg.enable {
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];
  };
}
