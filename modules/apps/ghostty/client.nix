{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ghostty
  ];

  hm.primary.xdg.configFile."ghostty/config.ghostty".text = ''
    confirm-close-surface = false
    bell-features = no-audio
    clipboard-write = allow
    copy-on-select = clipboard
  '';
}
