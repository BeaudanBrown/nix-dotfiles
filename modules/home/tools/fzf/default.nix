{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.fzf;
in
{
  options.${namespace}.tools.fzf = with types; {
    enable = mkBoolOpt false "Whether or not to enable fzf.";
  };

  config = mkIf cfg.enable {
    programs.fzf = {
      enable = true;
    };
  };
}
