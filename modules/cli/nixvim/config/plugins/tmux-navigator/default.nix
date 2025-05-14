{ ... }:
{
  plugins.tmux-navigator = {
    enable = true;
    settings = {
      no_wrap = 1;
    };
  };
  keymaps = [
    {
      key = "<A-h>";
      action = ''<cmd>TmuxNavigateLeft<CR>'';
      mode = [
        "n"
        "v"
        "i"
        "c"
        "x"
        "t"
      ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-j>";
      action = ''<cmd>TmuxNavigateDown<CR>'';
      mode = [
        "n"
        "v"
        "i"
        "c"
        "x"
        "t"
      ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-k>";
      action = ''<cmd>TmuxNavigateUp<CR>'';
      mode = [
        "n"
        "v"
        "i"
        "c"
        "x"
        "t"
      ];
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      key = "<A-l>";
      action = ''<cmd>TmuxNavigateRight<CR>'';
      mode = [
        "n"
        "v"
        "i"
        "c"
        "x"
        "t"
      ];
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}
