{ pkgs, ... }:
{
  programs.rbw = {
    enable = true;
    settings = {
      base_url = "https://pw.beaudan.me";
      email = "beaudan.brown@gmail.com";
      pinentry = pkgs.pinentry-rofi;
    };
  };
}
