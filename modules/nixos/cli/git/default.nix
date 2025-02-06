{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.git;
in {
  options.${namespace}.cli.git = {
    enable = mkBoolOpt false "Whether to enable git configuration.";
  };

  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      config = {
        user = {
          name = "Beaudan Brown";
          email = "beaudan.brown@gmail.com";
        };
        alias = {
          lg = "log --all --graph --decorate --oneline";
        };
      };
    };
  };
}
