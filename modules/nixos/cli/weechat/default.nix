{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.weechat;
in {
  options.${namespace}.cli.weechat = {
    enable = mkBoolOpt false "Whether to enable weechat configuration.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.weechat ];
    };
  };
}
