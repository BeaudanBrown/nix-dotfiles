{ ... }:
{
  plugins.treesitter = {
    enable = true;
    settings = {
      # TODO: this seems broken
      highlight.enable = false;
      # highlight.enable = true;
      indent.enable = true;
    };
  };
}
