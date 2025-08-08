{ config, ... }:
{
  services.blueman.enable = true;

  home-manager.users.${config.hostSpec.username}.services.blueman-applet.enable = true;
}
