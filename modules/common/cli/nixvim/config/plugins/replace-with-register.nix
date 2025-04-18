{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "replace-with-register";
        src = pkgs.fetchFromGitHub {
          owner = "inkarkat";
          repo = "vim-ReplaceWithRegister";
          rev = "b82bf59e5387b57d0125afb94fd7984061031136";
          hash = "sha256-Xq2/gWlSQVe6eSC3ODlTNXF1xbaUilPvkjcUzFguBT0=";
        };
      };
    }
  ];
}
