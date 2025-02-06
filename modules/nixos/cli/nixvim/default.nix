{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.nixvim;
in {
  options.${namespace}.cli.nixvim = {
    enable = mkBoolOpt false "Whether to enable nixvim configuration.";
  };

  config = mkIf cfg.enable {
    dotfiles.cli.nixvim.files = enabled;
    environment = {
      shellAliases.vim = "nvim";
      variables = {
        EDITOR = "nvim";
      };
    };

    programs.nixvim = (import ./config/nixvim.nix);
  };
}
