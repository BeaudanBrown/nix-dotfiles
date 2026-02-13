{ ... }:
{
  plugins.fugitive.enable = true;

  extraConfigLua = ''
    vim.api.nvim_create_user_command('GitClose', function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == "fugitive" then
          vim.api.nvim_buf_delete(bufnr, { force = false })
        end
      end
    end, {})

    vim.api.nvim_create_user_command('GitQuickCommit', function()
      vim.ui.input({ prompt = 'Commit Message: ' }, function(input)
        if input == nil then return end
        if input == "" then
          vim.cmd('Git commit')
        else
          vim.cmd('Git commit -m ' .. vim.fn.shellescape(input))
        end
      end)
    end, {})

    -- Auto-resize fugitive window when toggling/opening/closing inline diffs
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "fugitive",
      callback = function()
        vim.schedule(function()
          local buf = vim.api.nvim_get_current_buf()

          local function map_split(key, plug_map)
            vim.keymap.set('n', key, function()
              local total_width = vim.o.columns
              local cur_width = vim.api.nvim_win_get_width(0)
              local new_width

              if key == '=' then
                if (cur_width / total_width) < 0.5 then
                  new_width = math.floor(total_width * 0.7)
                else
                  new_width = math.floor(total_width * 0.3)
                end
              elseif key == '>' then
                new_width = math.floor(total_width * 0.7)
              elseif key == '<' then
                new_width = math.floor(total_width * 0.3)
              end

              local count = vim.v.count
              local count_str = (count > 0) and tostring(count) or ""
              -- Use <Cmd> for resize to avoid mode switching issues, and append to the plug map
              -- We use feedkeys with 'remap = true' ('m') so <Plug> is expanded
              local cmd = vim.api.nvim_replace_termcodes(count_str .. plug_map .. "<Cmd>vertical resize " .. new_width .. "<CR>", true, true, true)
              vim.api.nvim_feedkeys(cmd, 'm', false)
            end, { buffer = buf, desc = "Fugitive " .. key .. " with auto-resize" })
          end

          map_split('=', "<Plug>fugitive:=")
          map_split('>', "<Plug>fugitive:>")
          map_split('<', "<Plug>fugitive:<")

          -- Map Enter to open file and close fugitive window
          vim.keymap.set('n', '<CR>', function()
            local line = vim.fn.line('.')
            -- Get the fugitive buffer number before opening
            local fugitive_buf = vim.api.nvim_get_current_buf()
            -- Execute the default fugitive enter behavior (open file)
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>fugitive:Edit', true, true, true), 'm', false)
            -- Schedule the buffer close after the file opens
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(fugitive_buf) then
                vim.api.nvim_buf_delete(fugitive_buf, { force = false })
              end
            end)
          end, { buffer = buf, desc = 'Open file and close fugitive' })
        end)
      end,
    })
  '';

  keymaps = [
    {
      key = "<Leader>gs";
      action = "<cmd>lua vim.cmd('topleft vertical Git | vertical resize ' .. math.floor(vim.o.columns * 0.3))<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        desc = "Git status";
      };
    }
    {
      key = "<Leader>gd";
      action = "<cmd>Gdiffsplit<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        desc = "Git diff split";
      };
    }
    {
      key = "<Leader>gc";
      action = "<cmd>GitQuickCommit<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        desc = "Git commit";
      };
    }
    {
      key = "<Leader>gl";
      action = "<cmd>lua vim.cmd('topleft vertical Gclog | vertical resize ' .. math.floor(vim.o.columns * 0.3))<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        desc = "Git log";
      };
    }
    {
      key = "<Leader>gq";
      action = "<cmd>GitClose<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
        desc = "Close git status";
      };
    }
  ];
}
