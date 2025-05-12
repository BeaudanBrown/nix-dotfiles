{ ... }:
{
  plugins.lsp = {
    enable = true;
    # Delete the default keybings that clash with replace
    postConfig = ''
      vim.keymap.del('n', 'grn')
      vim.keymap.del('n', 'gra')
      vim.keymap.del('n', 'gri')
    '';
    servers = {
      gopls.enable = true;
      htmx.enable = true;
      jsonls.enable = true;
      pyright.enable = true;
      nixd.enable = true;
      air = {
        enable = true;
        onAttach.function = ''
          vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = bufnr,
              callback = function()
                  vim.lsp.buf.format()
              end,
          })
        '';
      };
      r_language_server = {
        enable = true;
        package = null;
      };
    };
    keymaps = {
      diagnostic = {
        "<leader>cj" = "goto_next";
        "<leader>ck" = "goto_prev";
      };
      lspBuf = {
        K = "hover";
        gD = "references";
        gd = "definition";
        gt = "type_definition";
        gI = "implementation";
      };
    };
  };
}
