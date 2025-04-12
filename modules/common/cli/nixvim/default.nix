{ ... }:
{
  imports = [ ./files ];
  environment = {
    shellAliases.vim = "nvim";
    variables = {
      EDITOR = "nvim";
    };
  };

  programs.nixvim = (import ./config/nixvim.nix);
}
