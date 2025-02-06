{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.services.docker;
in {
  options.${namespace}.services.docker = {
    enable = mkBoolOpt false "Whether or not to enable docker.";
  };

  config = mkIf cfg.enable {
    dotfiles.user.extraGroups = [ "docker" ];
    virtualisation = {
      docker = {
        enable = true;
        autoPrune = { enable = true; };
      };
    };
  };
}

