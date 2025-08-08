{ ... }:
{
  plugins.treesitter = {
    enable = true;
    settings = {
      # TODO: this seems broken
      # highlight.enable = true;
      indent.enable = true;
    };
  };
}
