{ lib, ...}:
let
  pluginFolder = ./plugins;
  files = builtins.attrNames (builtins.readDir pluginFolder);
  pluginFiles = map (file: (import "${pluginFolder}/${file}"){}) files;
  pluginKeymaps = builtins.concatMap (file: file.keymaps) pluginFiles;
in
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
      key = "<A-h>";
      action = ''<cmd>TmuxNavigateLeft<CR>'';
      mode = [ "n" "v" "i" "c" "x" "t" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-j>";
      action = ''<cmd>TmuxNavigateDown<CR>'';
      mode = [ "n" "v" "i" "c" "x" "t" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-k>";
      action = ''<cmd>TmuxNavigateUp<CR>'';
      mode = [ "n" "v" "i" "c" "x" "t" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-l>";
      action = ''<cmd>TmuxNavigateRight<CR>'';
      mode = [ "n" "v" "i" "c" "x" "t" ];
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
      action = '':lua close_buffer()<CR>'';
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
      key = "<Leader>t";
      action = '':vs term://zsh<CR>'';
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
      mode = [ "n" "v" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-o>";
      action = ''<C-o>zz'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-i>";
      action = ''<C-i>zz'';
      mode = [ "n" ];
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
      key = "<C-d>";
      action = ''<C-d>zz'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-u>";
      action = ''<C-u>zz'';
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
      key = "K";
      action = ''<cmd>lua vim.lsp.buf.hover()<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<C-j>";
      action = ''wildmenumode() ? "<C-z>" : "<C-n>"'';
      mode = [ "c" "n" "t" ];
      options = {
        expr = true;
        noremap = true;
      };
    }
    {
      key = "<C-k>";
      action = ''wildmenumode() ? "<Up>" : "<C-p>"'';
      mode = [ "c" "n" "t" ];
      options = {
        expr = true;
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
    {
      key = "<leader>gg";
      action = ''<cmd>LazyGit<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<c-P>";
      action = ''<cmd>ProjectFiles<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader><CR>";
      action = ''<cmd>AIChat<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>gk";
      action = ''<cmd>GitGutterPrevHunk<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>gj";
      action = ''<cmd>GitGutterNextHunk<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<Leader>gj";
      action = ''<cmd>GitGutterNextHunk<cr>'';
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
  ] ++ pluginKeymaps;
}
