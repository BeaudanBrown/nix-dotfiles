{
  pkgs,
  ...
}:
{
  environment.shellAliases = {
    htop = "${pkgs.btop}/bin/btop -u 500";
  };

  hm.primary.programs.btop.enable = true;
}
