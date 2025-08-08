{
  config,
  ...
}:
{
  home-manager.users.${config.hostSpec.username}.services.kdeconnect = {
    enable = true;
    indicator = true;
  };
}
