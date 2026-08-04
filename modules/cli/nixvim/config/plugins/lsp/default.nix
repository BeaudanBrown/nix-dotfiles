{ pkgs, ... }:
{
  plugins.lsp = {
    enable = true;
    # Delete the default keybings that clash with replace
    postConfig = ''
      vim.keymap.del('n', 'grn')
      vim.keymap.del('n', 'gra')
      vim.keymap.del('n', 'gri')

      -- Keep `r_language_server` attached for lintr diagnostics only. R.nvim's
      -- rnvimserver handles completion, and air handles formatting. Disabling
      -- the overlapping capabilities also avoids an upstream languageserver
      -- crash when completing arguments whose defaults use namespaced calls.
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == 'r_language_server' then
            client.server_capabilities.completionProvider = nil
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
        end,
      })
    '';
    servers = {
      hls = {
        enable = true;
        installGhc = true;
        packageFallback = true;
      };
      gopls.enable = true;
      htmx = {
        enable = true;
        filetypes = [ "html" ];
      };
      jsonls.enable = true;
      pyright.enable = true;
      nixd = {
        settings.formatting.command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
        enable = true;
      };
      air = {
        enable = true;
      };
      r_language_server = {
        enable = true;
        package = null;
      };
      rust_analyzer = {
        enable = true;
        installCargo = true;
        installRustc = true;
        settings = {
          check = {
            command = "clippy";
          };
        };
      };
      ruff = {
        enable = true;
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
        "<localleader>f" = "format";
      };
    };
  };
}
