{
  pkgs,
  config,
  ...
}:
{
  environment.shellAliases = {
    htop = ''${pkgs.btop}/bin/btop'';
  };

  home-manager.users.${config.hostSpec.username}.programs.btop.enable = true;
}
