{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    audacity
    calibre
    caprine
    discord
    gparted
    nautilus
    qbittorrent
    signal-desktop-bin
    spotify
    sxiv
    tor-browser
    vlc
    zoom-us
  ];
  programs.autojump.enable = true;
  programs.kdeconnect.enable = true;
}
