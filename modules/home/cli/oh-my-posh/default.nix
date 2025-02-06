{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.oh-my-posh;
in {
  options.${namespace}.cli.oh-my-posh = {
    enable = mkBoolOpt false "Whether to enable oh-my-posh.";
  };

  config = mkIf cfg.enable {
    programs.oh-my-posh = {
      enable = true;
      settings = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile ./config/oh-my-posh.json));
      enableZshIntegration = true;
    };
  };
}
