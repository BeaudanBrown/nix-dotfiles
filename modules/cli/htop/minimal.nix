{
  pkgs,
  ...
}:
{
  environment.shellAliases = {
    htop = ''${pkgs.btop}/bin/btop'';
  };

  hm.programs.btop.enable = true;
}
