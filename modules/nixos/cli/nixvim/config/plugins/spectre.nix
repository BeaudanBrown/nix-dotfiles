{...}:
{
  plugins.spectre = {
    enable = true;
    settings = {
      mapping = {
        send_to_qf = {
          map = "<Leader>Q";
          cmd = "<cmd>lua require('spectre.actions').send_to_qf()<CR>";
          desc = "send all items to quickfix";
        };
      };
    };
  };
  keymaps = [
    {
      key = "<Leader>R";
      action = ''<cmd>lua require('spectre').open_visual({select_word=true})<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}

