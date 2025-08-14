{ pkgs, ... }:
{
  extraPlugins = [
    pkgs.vimPlugins.denops-vim
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "vim-gin";
        src = pkgs.fetchFromGitHub {
          owner = "lambdalisue";
          repo = "vim-gin";
          rev = "7c4b98011a2d5bdf7342031f9c8ae7a1c11b584b";
          hash = "sha256-IKnjAGwXxIUi9DN2EtmPJbojCP0IhQhDppZDBUNYNGQ=";
        };
      };
    }
  ];
  # extraConfigLua = ''
  #   vim.g.vim_ai_chat = {
  #     options = {
  #       endpoint_url = "https://litellm.bepis.lol/v1/chat/completions",
  #     },
  #   }
  #   vim.g.vim_ai_roles_config_file  = "${./roles.ini}"
  # '';
  keymaps = [
    {
      key = "<Leader>gs";
      action = ''<cmd>GinStatus<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>gl";
      action = ''<cmd>GinLog<CR>'';
      mode = [ "n" ];

      options = {
        noremap = true;
      };
    }
  ];
}
