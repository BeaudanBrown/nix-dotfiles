{
  pkgs,
  ...
}:
{
  environment.shellAliases = {
    htop = ''${pkgs.btop}/bin/btop -u 500'';
  };

  hm.programs.btop.enable = true;
}
