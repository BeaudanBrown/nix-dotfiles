{ ... }:
{
  plugins.yazi = {
    enable = true;
    settings = {
      open_for_directories = true;
    };
  };
  keymaps = [
    {
      key = "<Leader>e";
      action = ''<cmd>lua require("yazi").yazi()<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}
