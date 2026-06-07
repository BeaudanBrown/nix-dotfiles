{ ... }:
{
  # hmts.nvim 1.3.0 currently crashes Neovim 0.12 tree-sitter on Nix files
  # with: attempt to call method 'parent' (a nil value).
  plugins.hmts.enable = false;
}
