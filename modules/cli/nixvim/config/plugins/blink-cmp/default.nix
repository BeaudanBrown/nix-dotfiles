{ ... }:
{
  plugins.blink-cmp = {
    enable = true;
    settings = {
      keymap = {
        "<C-b>" = [
          "scroll_documentation_up"
        ];
        "<C-f>" = [
          "scroll_documentation_down"
        ];
        "<C-j>" = [
          "select_next"
        ];
        "<C-k>" = [
          "select_prev"
        ];
        "<CR>" = [
          "select_and_accept"
          "fallback"
        ];
      };
    };
  };
  # cmp = {
  #   enable = true;
  #   autoEnableSources = true;
  #   settings = {
  #     preselect = "cmp.PreselectMode.None";
  #     snippet = {
  #       expand = "function(args) require('luasnip').lsp_expand(args.body) end";
  #     };
  #     mapping = {
  #       "<C-b>" = "cmp.mapping.scroll_docs(-4)";
  #       "<C-f>" = "cmp.mapping.scroll_docs(4)";
  #       "<C-e>" = "cmp.mapping.abort()";
  #       "<CR>" = "cmp.mapping.confirm({ select = true })";
  #       "<C-j>" = "cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert })";
  #       "<C-k>" = "cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert })";
  #       "<Tab>" = ''
  #         function(fallback)
  #           if require("luasnip").expand_or_jumpable() then
  #             vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
  #           else
  #             fallback()
  #           end
  #         end
  #       '';
  #       "<S-Tab>" = ''
  #         function(fallback)
  #           if require("luasnip").jumpable(-1) then
  #             vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
  #           else
  #             fallback()
  #           end
  #         end
  #       '';
  #     };
  #     sources = [
  #       { name = "luasnip"; }
  #       { name = "nvim_lsp"; }
  #       { name = "spell"; }
  #       { name = "path"; }
  #       { name = "buffer"; }
  #     ];
  #   };
  # };
}
