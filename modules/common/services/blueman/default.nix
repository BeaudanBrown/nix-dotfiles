{ ... }:
{
  services.blueman.enable = true;
  home-manager.sharedModules = [
    {
      services.blueman-applet.enable = true;
    }
  ];
}
