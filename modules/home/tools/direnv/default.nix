{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.direnv;
in
{
  options.${namespace}.tools.direnv = with types; {
    enable = mkBoolOpt false "Whether or not to enable direnv.";
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      config = {
        whitelist = {
          prefix = [
            "${config.home.homeDirectory}/documents"
            "${config.home.homeDirectory}/monash"
            "${config.home.homeDirectory}/collab"
          ];
        };
      };
    };
  };
}
