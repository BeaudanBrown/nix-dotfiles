{ self, ...}:
  {
    imports = let
      pluginFolder = ./plugins;
      files = builtins.attrNames (builtins.readDir pluginFolder);
      pluginFiles = map (file: "${pluginFolder}/${file}") files;
    in
    [
      ./keybinds.nix
      ./extraPlugins.nix
    ] ++ pluginFiles;

    enable = true;

    clipboard.register = [ "unnamed" "unnamedplus" ];
    colorschemes.kanagawa = {
      enable = true;
      settings.theme = "dragon";
    };

    plugins = {
      otter.enable = true;
      lualine.enable = true;
      nvim-colorizer.enable = true;
      commentary.enable = true;
      vim-surround.enable = true;
      vimtex.enable = true;
      nix.enable = true;
      treesitter = {
        settings = {
          highlight.enable = true;
        };
        enable = true;
      };
      # TODO: add config for escape to close
      lazygit.enable = true;
      friendly-snippets.enable = true;
      fzf-lua = {
        enable = true;
        settings = {
          files = {
            cmd = "rg --files";
          };
          winopts = {
            height = 0.9;
            width = 0.9;
            preview = {
              horizontal = "right:40%";
            };
          };
        };
      };
      vim-slime = {
        enable = true;
        settings = {
          dont_ask_default = 1;
          target = "tmux";
          default_config = {
            socket_name = "default";
            target_pane  = "{right}";
          };
        };
      };
      tmux-navigator = {
        enable = true;
        settings = {
          no_wrap = 1;
        };
      };
      gitgutter = {
        enable = true;
        terminalReportFocus = true;
      };
      lsp = {
        enable = true;
        servers = {
          gopls.enable = true;
          htmx.enable = true;
          jsonls.enable = true;
          lua_ls.enable = true;
          pyright.enable = true;
          nixd.enable = true;
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
          };
        };
      };
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          preselect = "cmp.PreselectMode.None";
          snippet = {
            expand = "function(args) require('luasnip').lsp_expand(args.body) end";
          };
          mapping = {
            "<C-b>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<C-j>" = "cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert })";
            "<C-k>" = "cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert })";
            "<Tab>" = ''
              function(fallback)
                if require("luasnip").expand_or_jumpable() then
                  vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
                else
                  fallback()
                end
              end
            '';
            "<S-Tab>" = ''
              function(fallback)
                if require("luasnip").jumpable(-1) then
                  vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
                else
                  fallback()
                end
              end
            '';
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
        };
      };
      luasnip.enable = true;
    };

    opts = {
      autowrite = true;
      completeopt = "menu";
      background = "dark";
      hidden = true;
      mouse = "a";
      encoding = "utf-8";
      expandtab = true;
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      autoindent = true;
      smartindent = true;
      incsearch = true;
      number = true;
      splitbelow = true;
      splitright = true;
      wildmode = "list:longest";
      wildignorecase = true;
      ignorecase = true;
      smartcase = true;
      hlsearch = true;
      showmatch = true;
      updatetime = 100;
      errorbells = false;
      undofile = true;
      inccommand = "nosplit";
      signcolumn = "yes";
      nrformats = "";
      history = 1000;
      diffopt = "vertical";
      autoread = true;
      previewheight = 40;
      list = true;
      listchars = "tab:·\\ ,trail:~";
      backspace = ["indent" "eol" "start"];
      undodir.__raw = ''os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config" .. "/undodir//"'';
      directory.__raw = ''os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config" .. "/swp//"'';
    };

    globals = {
      mapleader = " ";
      highlightedyank_highlight_duration = 200;
    };

    autoGroups = {
      cursor_pos = {
        clear = true;
      };
    };

    autoCmd = [
      {
        desc = "Save cursor and pane position";
        event = [ "BufLeave" ];
        group = "cursor_pos";
        callback = {
          __raw = ''
          function()
          local buf = vim.api.nvim_get_current_buf()
          vim.b[buf].last_cursor_pos = vim.api.nvim_win_get_cursor(0)
          vim.b[buf].last_window_view = vim.fn.winsaveview()
          end'';
        };
      }
      {
        desc = "Restore cursor and pane position";
        event = [ "BufEnter" ];
        group = "cursor_pos";
        callback = {
          __raw = ''
          function()
          local buf = vim.api.nvim_get_current_buf()
          if vim.b[buf].last_cursor_pos then
          vim.api.nvim_win_set_cursor(0, vim.b[buf].last_cursor_pos)
          pcall(vim.fn.winrestview, vim.b[buf].last_window_view)
          end
          end'';
        };
      }
      {
        event = [ "TermOpen" "WinEnter" ];
        pattern = "term://*";
        command = "startinsert";
      }
    ];

    highlightOverride = {
      GitGutterAdd.bold = true;
      GitGutterChange.bold = true;
      GitGutterDelete.bold = true;
      CursorLine = {
        ctermfg = "NONE";
        ctermbg = "NONE";
      };
      LineNr = {
        ctermbg = "NONE";
      };
      SignColumn = {
        ctermfg = "NONE";
        ctermbg = "NONE";
      };
      IncSearch.bold = true;
    };

    extraConfigLua = ''
    local find_root = function()
      local gitRoot = vim.fn.system('git rev-parse --show-toplevel 2> /dev/null')
      if gitRoot ~= "" then
        gitRoot = vim.fn.trim(gitRoot)
        if vim.fn.filereadable(gitRoot .. '/.git') == 1 then
          -- We are in a git folder
          return gitRoot
        end
      end
      -- We are in a non-git folder or in the root of the git folder
      if #vim.fn.argv() > 0 then
        return vim.fn.fnamemodify(vim.fn.argv()[0], ':p:h')
      end
      return vim.fn.getcwd()
    end
    local root = find_root()
    vim.api.nvim_create_user_command('ProjectFiles', function() vim.cmd('FzfLua files ' .. root) end, {})
    '';
  }
