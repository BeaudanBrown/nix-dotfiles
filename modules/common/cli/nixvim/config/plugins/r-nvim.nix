{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "r-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "R-nvim";
          repo = "r.nvim";
          rev = "964075526267bf5768d14b6be83bea7a17ada56f";
          hash = "sha256-lgusti4dehig3+4Z/SadzfrErFHzDNGrXs69NLAHwKA=";
        };
      };
    }
  ];
}
