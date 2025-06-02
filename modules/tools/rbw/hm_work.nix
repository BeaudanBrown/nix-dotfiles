{ pkgs, nixpkgsUnstable, ... }:
let
  pkgsUnstable = nixpkgsUnstable.legacyPackages.${pkgs.system};
in
{
  programs.rbw = {
    enable = true;
    package = pkgsUnstable.rbw;
    settings = {
      base_url = "https://pw.beaudan.me";
      email = "beaudan.brown@gmail.com";
      pinentry = pkgs.pinentry-rofi;
    };
  };
}
