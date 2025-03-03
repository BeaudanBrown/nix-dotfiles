{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.nixvim.files;
in {
  options.${namespace}.cli.nixvim.files = {
    enable = mkBoolOpt false "Whether to put nixvim related files in home directory.";
  };

  config = mkIf cfg.enable {
    dotfiles.home.file.".local/share/gpt/default.aichat".source = ./default.aichat;
    dotfiles.home.file.".local/share/gpt/o3-mini.aichat".source = ./o3-mini.aichat;
  };
}
