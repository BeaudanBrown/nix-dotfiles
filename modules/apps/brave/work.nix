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
    "SpellcheckEnabled" = true;
    "SpellcheckLanguage" = [
      "en-AU"
    ];
    "DefaultDownloadDirectory" = "${config.hostSpec.home}/downloads";
  };
}
