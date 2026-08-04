{ ... }:
{
  plugins = {
    lz-n.enable = true;
    lualine.enable = true;
    colorizer.enable = true;
    commentary.enable = true;
    vim-surround.enable = true;
    markdown-preview.enable = true;
    nix.enable = true;
    diffview.enable = true;
    otter = {
      enable = true;
      # Quarto activates Otter for embedded-language buffers itself. Global
      # LspAttach activation recursively reactivates Otter on its own virtual
      # buffers and on R.nvim's language server.
      autoActivate = false;
    };
  };
}
