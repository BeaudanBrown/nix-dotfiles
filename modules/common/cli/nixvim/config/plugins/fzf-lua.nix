{ pkgs, ... }:
{
  plugins.fzf-lua = {
    enable = true;
    settings = {
      files = {
        cmd = "${pkgs.ripgrep}/bin/rg --files -g '!.git'";
      };
      winopts = {
        height = 0.9;
        width = 0.9;
        preview = {
          horizontal = "right:40%";
        };
      };
    };
  };
  keymaps = [
    {
      key = "<c-P>";
      action = ''<cmd>ProjectFiles<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>;";
      action = '':FzfLua command_history<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>f";
      action = '':FzfLua grep_project<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>F";
      action = '':FzfLua grep_cword<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>l";
      action = '':FzfLua lines<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>b";
      action = '':FzfLua buffers<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
  ];
}
