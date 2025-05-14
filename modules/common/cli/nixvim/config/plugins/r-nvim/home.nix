{ osConfig, ... }:
{

  home.file.".Rprofile" =
    let
      profile = ''
        function() {
          options(browser = "brave")
        }
      '';
    in
    {
      text = profile;
      target = "${osConfig.hostSpec.home}/.config/Rprofile";
    };
}
