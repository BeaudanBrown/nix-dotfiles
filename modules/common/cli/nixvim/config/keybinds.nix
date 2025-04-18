{ ... }:
{
  keymaps = [
    {
      key = "<Space>";
      action = ''<Nop>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader>S";
      action = '':%s/\<<C-r>=expand('<cword>')<CR>\>//g<Left><Left>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>S";
      action = ''"ay:%s/<C-r>a//g<Left><Left>'';
      mode = [ "v" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>d";
      action = ''<Plug>CloseBuffer<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Space>";
      action = ''<Nop>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader><Leader>";
      action = ''<C-^>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader>q";
      action = '':q<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader>s";
      action = '':w<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader>p";
      action = '':pu<CR>==$'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader>/";
      action = '':noh<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<Leader>=";
      action = ''<C-w>='';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-q>";
      action = ''<C-\><C-n>'';
      mode = [ "t" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "S";
      action = '':%s//g<Left><Left>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "S";
      action = '':s//g<Left><Left>'';
      mode = [ "v" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "Q";
      action = ''@@'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "s";
      action = ''"_s'';
      mode = [
        "n"
        "v"
      ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "j";
      action = ''gj'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "k";
      action = ''gk'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-u>";
      action = "M<Cmd>lua vim.cmd('normal! <C-u>')<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-d>";
      action = "M<Cmd>lua vim.cmd('normal! <C-d>')<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-left>";
      action = ''3<c-w><'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-right>";
      action = ''3<c-w>>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-up>";
      action = ''3<c-w>+'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-down>";
      action = ''3<c-w>-'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-j>";
      action = ''wildmenumode() ? "<C-z>" : "<C-n>"'';
      mode = [
        "c"
        "n"
        "t"
      ];
      options = {
        expr = true;
        noremap = true;
      };
    }
    {
      key = "<C-k>";
      action = ''wildmenumode() ? "<Up>" : "<C-p>"'';
      mode = [
        "c"
        "n"
        "t"
      ];
      options = {
        expr = true;
        noremap = true;
      };
    }
  ];
}
