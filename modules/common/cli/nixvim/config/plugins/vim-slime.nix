{ ... }:
{
  plugins.vim-slime = {
    enable = true;
    settings = {
      dont_ask_default = 1;
      target = "tmux";
      default_config = {
        socket_name = "default";
        target_pane = "{right}";
      };
    };
  };
}
