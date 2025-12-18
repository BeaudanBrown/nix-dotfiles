{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "r-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "R-nvim";
          repo = "r.nvim";
          rev = "42b6321c771c902200ecd18791b4ca48e029a62e";
          hash = "sha256-WhN2L5Uv/7HSm/nZHzJiDy3EAnZ2b8cDzG+D7xPvDUk=";
        };
        nvimSkipModules = [
          "r.pdf.sumatra"
          "r.roxygen"
          "r.format"
        ];
      };
    }
  ];
  extraConfigLua = ''
    require("r").setup {
      rconsole_width = 66,
      rconsole_height = 0
    }

    -- Targets package keybindings
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "r", "rmd", "quarto" },
      callback = function()
        local opts = { noremap = true, silent = true, buffer = true }

        -- Helper function to get function name cursor is inside
        local function get_current_function_name()
          local ts_utils = require('nvim-treesitter.ts_utils')
          local bufnr = vim.api.nvim_get_current_buf()

          local cursor_node = ts_utils.get_node_at_cursor()
          if not cursor_node then return nil end

          -- Walk up to find function definition
          local func_node = cursor_node
          while func_node do
            if func_node:type() == "binary_operator" then
              -- Look for pattern: name <- function(...)
              local left = func_node:named_child(0)
              local op = func_node:child(1)
              local right = func_node:named_child(1)

              if left and right and vim.treesitter.get_node_text(op, bufnr):match("<-") then
                if right:type() == "function_definition" then
                  return vim.treesitter.get_node_text(left, bufnr)
                end
              end
            end
            func_node = func_node:parent()
          end

          return nil
        end

        -- Helper function to search for tar_target calls in a file
        local function search_file_for_targets(filepath, func_name, targets, seen)
          local parsers = require('nvim-treesitter.parsers')

          -- Read file contents
          local content = vim.fn.readfile(filepath)
          if not content or #content == 0 then return end

          -- Join content into a single string
          local source = table.concat(content, "\n")

          -- Create a parser for this content
          local file_parser = vim.treesitter.get_string_parser(source, 'r')
          if not file_parser then return end

          local trees = file_parser:parse()
          if not trees or #trees == 0 then return end

          local root = trees[1]:root()

          -- Recursively search for tar_target calls
          local function find_tar_target_calls(node)
            if node:type() == "call" then
              local func = node:named_child(0)
              if func then
                local func_text = vim.treesitter.get_node_text(func, source)

                -- Check if this is a tar_target call
                if func_text:match("tar_target") then
                  -- Look for the command argument
                  local args = node:named_child(1)
                  if args and args:type() == "arguments" then
                    for child in args:iter_children() do
                      -- Look for command = ... or second positional argument
                      if child:type() == "argument" then
                        local arg_name_node = child:child(0)
                        local arg_value = child:named_child(0)

                        -- Check if this is the command argument (named or positional)
                        local is_command = false
                        if arg_name_node and arg_name_node:type() == "identifier" then
                          local arg_name = vim.treesitter.get_node_text(arg_name_node, source)
                          if arg_name == "command" then
                            is_command = true
                            arg_value = child:named_child(1) or child:named_child(0)
                          end
                        else
                          -- Could be second positional argument (first is name)
                          is_command = true
                        end

                        if is_command and arg_value and arg_value:type() == "call" then
                          local called_func = arg_value:named_child(0)
                          if called_func then
                            local called_func_name = vim.treesitter.get_node_text(called_func, source)

                            -- Check if this matches our function
                            if called_func_name == func_name then
                              -- Extract arguments passed to this function
                              local call_args = arg_value:named_child(1)
                              if call_args and call_args:type() == "arguments" then
                                for arg in call_args:iter_children() do
                                  if arg:type() == "argument" or arg:type() == "identifier" then
                                    local arg_text = vim.treesitter.get_node_text(arg, source)
                                    -- Extract just the identifier, not named args
                                    local identifier = arg_text:match("^%s*([%w_%.]+)")
                                    if identifier and not seen[identifier] then
                                      seen[identifier] = true
                                      table.insert(targets, identifier)
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end

            -- Recurse through all children
            for child in node:iter_children() do
              find_tar_target_calls(child)
            end
          end

          find_tar_target_calls(root)
        end

        -- Helper function to extract arguments from tar_target calls across files
        local function get_targets_for_function(func_name)
          if not func_name then return {} end

          local targets = {}
          local seen = {}

          -- Find project root (look for _targets.R or .git)
          local cwd = vim.fn.getcwd()
          local project_root = cwd

          -- Search for R files in common locations
          local search_patterns = {
            "_targets.R",           -- Main targets file
            "*.R",                  -- Root R files
            "R/*.R",                -- R package style
            "r/*.R",                -- Lowercase variant
            "analysis/*.R",         -- Analysis scripts
            "scripts/*.R",          -- Scripts directory
          }

          local files_to_search = {}
          for _, pattern in ipairs(search_patterns) do
            local found = vim.fn.glob(cwd .. "/" .. pattern, false, true)
            for _, file in ipairs(found) do
              if vim.fn.filereadable(file) == 1 then
                table.insert(files_to_search, file)
              end
            end
          end

          -- Search each file
          for _, filepath in ipairs(files_to_search) do
            search_file_for_targets(filepath, func_name, targets, seen)
          end

          return targets
        end

        -- Load target under cursor: <leader>tl
        vim.keymap.set("n", "<leader>tl", function()
          local target = vim.fn.expand('<cword>')
          require('r.send').cmd(string.format('targets::tar_load(%s)', target))
        end, vim.tbl_extend("force", opts, { desc = "targets: Load target under cursor" }))

        -- Load all targets passed as arguments to current function: <leader>tL
        vim.keymap.set("n", "<leader>tL", function()
          local func_name = get_current_function_name()
          if not func_name then
            vim.notify("Not inside a named function definition", vim.log.levels.WARN)
            return
          end

          local targets = get_targets_for_function(func_name)
          if #targets == 0 then
            vim.notify(string.format("No tar_target calls found for function '%s'", func_name), vim.log.levels.INFO)
            return
          end

          local targets_str = table.concat(vim.tbl_map(function(t)
            return string.format('"%s"', t)
          end, targets), ", ")

          vim.notify(string.format("Loading targets for %s: %s", func_name, table.concat(targets, ", ")), vim.log.levels.INFO)
          require('r.send').cmd(string.format('targets::tar_load(c(%s))', targets_str))
        end, vim.tbl_extend("force", opts, { desc = "targets: Load args for current function" }))

        -- Make target under cursor: <leader>tm
        vim.keymap.set("n", "<leader>tm", function()
          local target = vim.fn.expand('<cword>')
          require('r.send').cmd(string.format('targets::tar_make(%s)', target))
        end, vim.tbl_extend("force", opts, { desc = "targets: Make target under cursor" }))

        -- Make all targets: <leader>tM
        vim.keymap.set("n", "<leader>tM", function()
          require('r.send').cmd('targets::tar_make()')
        end, vim.tbl_extend("force", opts, { desc = "targets: Make all targets" }))

        -- Read target under cursor: <leader>tr
        vim.keymap.set("n", "<leader>tr", function()
          local target = vim.fn.expand('<cword>')
          require('r.send').cmd(string.format('targets::tar_read(%s)', target))
        end, vim.tbl_extend("force", opts, { desc = "targets: Read target under cursor" }))

        -- Visualize targets pipeline: <leader>tv
        vim.keymap.set("n", "<leader>tv", function()
          require('r.send').cmd('targets::tar_visnetwork()')
        end, vim.tbl_extend("force", opts, { desc = "targets: Visualize pipeline" }))

        -- Invalidate target under cursor: <leader>ti
        vim.keymap.set("n", "<leader>ti", function()
          local target = vim.fn.expand('<cword>')
          require('r.send').cmd(string.format('targets::tar_invalidate(%s)', target))
        end, vim.tbl_extend("force", opts, { desc = "targets: Invalidate target under cursor" }))

        -- Show target progress: <leader>tp
        vim.keymap.set("n", "<leader>tp", function()
          require('r.send').cmd('targets::tar_progress()')
        end, vim.tbl_extend("force", opts, { desc = "targets: Show progress" }))

        -- Show target manifest: <leader>ts
        vim.keymap.set("n", "<leader>ts", function()
          require('r.send').cmd('targets::tar_manifest()')
        end, vim.tbl_extend("force", opts, { desc = "targets: Show manifest" }))
      end,
    })
  '';
}
