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

  programs.chromium.defaultSearchProviderEnabled = true;
  programs.chromium.defaultSearchProviderSearchURL = "https://encrypted.google.com/search?q={searchTerms}&{google:RLZ}{google:originalQueryForSuggestion}{google:assistedQueryStats}{google:searchFieldtrialParameter}{google:searchClient}{google:sourceId}{google:instantExtendedEnabledParameter}ie={inputEncoding}";
  programs.chromium.extraOpts = {
    "PasswordManagerEnabled" = false;
    "PasswordManagerPasskeysEnabled" = false;
    "SpellcheckEnabled" = true;
    "SpellcheckLanguage" = [ "en-AU" ];
    "DefaultDownloadDirectory" = "${config.hostSpec.home}/downloads";
    "DefaultNotificationsSetting" = 2;
    "AutofillCreditCardEnabled" = false;
    "AutofillAddressEnabled" = false;
  };

  hm.xdg = {
    mimeApps = {
      enable = true;
      # to see available > ls /run/current-system/sw/share/applications/
      defaultApplications = {
        "x-scheme-handler/http" = [ "brave-browser.desktop" ];
        "x-scheme-handler/https" = [ "brave-browser.desktop" ];
      };
    };
  };
}
