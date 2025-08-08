{
  config,
  ...
}:
{
  home-manager.users.${config.hostSpec.username}.services.dunst = {
    enable = true;
  };
}
