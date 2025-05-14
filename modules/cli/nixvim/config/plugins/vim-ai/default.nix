{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "vim-ai";
        src = pkgs.fetchFromGitHub {
          owner = "madox2";
          repo = "vim-ai";
          rev = "380d5cdd9538c2522dfc8d03a8a261760bb0439a";
          hash = "sha256-ywnBM2YBysrs5EF0lpxKH0cYXJZvFgL+F9f+kCuiFJ8=";
        };
      };
    }
  ];
  extraConfigLua = ''
    vim.g.vim_ai_chat = {
      options = {
        endpoint_url = "https://litellm.bepis.lol/v1/chat/completions",
      },
    }
    vim.g.vim_ai_roles_config_file  = "${./roles.ini}"
  '';
  keymaps = [
    {
      key = "<Leader><CR>";
      action = ''<cmd>AIChat<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
  ];
}
