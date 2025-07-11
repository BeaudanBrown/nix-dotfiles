{
  pkgs,
  ...
}:
{
  environment.shellAliases = {
    htop = ''${pkgs.btop}/bin/btop'';
  };
}
