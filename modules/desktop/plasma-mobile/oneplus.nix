{
  config,
  lib,
  pkgs,
  ...
}:
{
  hardware.graphics.enable = true;
  hardware.sensor.iio.enable = true;

  services.desktopManager.plasma6 = {
    enable = true;
    enableQt5Integration = false;
  };

  services.displayManager = {
    defaultSession = lib.mkForce "plasma-mobile";
    sessionPackages = [ pkgs.kdePackages.plasma-mobile ];

    autoLogin = {
      enable = true;
      user = config.hostSpec.username;
    };

    sddm = {
      enable = true;
      wayland = {
        enable = true;
        compositor = "kwin";
      };
      extraPackages = with pkgs; [
        qt6.qtvirtualkeyboard
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    kdePackages.plasma-mobile
    maliit-framework
    maliit-keyboard
    qt6.qtvirtualkeyboard

    gnome-console
    git
    tmux
    vim
  ];

  programs.feedbackd.enable = true;
  programs.calls.enable = true;
  services.libinput.enable = true;
}
