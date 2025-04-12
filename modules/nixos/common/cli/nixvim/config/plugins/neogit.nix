{ ... }:
{
  plugins.neogit = {
    enable = true;
    settings = {
      kind = "floating";
      mappings = {
        status = {
          "<esc>" = "Close";
        };
      };
    };
  };
  keymaps = [
    {
      key = "<Leader>gg";
      action = ''<cmd>Neogit<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}
