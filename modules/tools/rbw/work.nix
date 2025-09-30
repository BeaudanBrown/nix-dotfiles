{
  pkgs,
  ...
}:
{
  hm.programs.rbw = {
    enable = true;
    settings = {
      base_url = "https://pw.bepis.lol";
      email = "beaudan.brown@gmail.com";
      pinentry = pkgs.pinentry-rofi;
    };
  };
}
