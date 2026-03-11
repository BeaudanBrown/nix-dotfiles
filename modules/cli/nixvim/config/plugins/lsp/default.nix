{ pkgs, ... }:
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
      hls = {
        enable = true;
        installGhc = true;
        packageFallback = true;
      };
      gopls.enable = true;
      htmx.enable = true;
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
