{ options
, config
, pkgs
, lib
, namespace
, ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.locale;
in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt true "Whether or not to locale.";
  };

  config = mkIf cfg.enable {
    # Set your time zone.
    time.timeZone = "Australia/Melbourne";

    # Select internationalisation properties.
    i18n = {
      defaultLocale = "en_AU.UTF-8";
      extraLocaleSettings = {
        LANG = "en_AU.UTF-8";
        LC_ALL = "en_AU.UTF-8";
        LANGUAGE = "en_AU.UTF-8";
        LC_ADDRESS = "en_AU.UTF-8";
        LC_IDENTIFICATION = "en_AU.UTF-8";
        LC_MEASUREMENT = "en_AU.UTF-8";
        LC_MONETARY = "en_AU.UTF-8";
        LC_NAME = "en_AU.UTF-8";
        LC_NUMERIC = "en_AU.UTF-8";
        LC_PAPER = "en_AU.UTF-8";
        LC_TELEPHONE = "en_AU.UTF-8";
        LC_TIME = "en_AU.UTF-8";
      };
    };
  };
}
