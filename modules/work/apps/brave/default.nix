{
  pkgs,
  config,
  ...
}:
{
  environment = {
    systemPackages = [ pkgs.brave ];
    variables.BROWSER = "brave";
  };

  programs.chromium.extraOpts = {
    "PasswordManagerEnabled" = false;
    "SpellcheckEnabled" = true;
    "SpellcheckLanguage" = [
      "en-AU"
    ];
    "DefaultDownloadDirectory" = "${config.hostSpec.home}/downloads";
  };
}
