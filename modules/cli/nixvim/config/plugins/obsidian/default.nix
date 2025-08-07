{ ... }:
{
  plugins.obsidian = {
    enable = true;
    # TODO: Make this work properly
    # luaConfig.post = ''
    #   require("obsidian").setup {
    #     callbacks = {
    #       enter_note = function(_, note)
    #         vim.keymap.set("n", "<localleader><localleader>", "<cmd>Obsidian toggle_checkbox<cr>", {
    #           buffer = note.bufnr,
    #           desc = "Toggle checkbox",
    #         })
    #       end,
    #     },
    #   }
    # '';
    settings = {
      legacy_commands = false;
      workspaces = [
        {
          name = "main";
          path = "~/documents/vault/main";
        }
      ];
      follow_url_func = ''
        function(url)
          vim.fn.jobstart({"xdg-open", url}, { detach = true })
          vim.fn.jobstart({'hyprctl', 'dispatch', 'focuswindow', 'class:brave-browser'}, { detach = true })
        end'';

      ui = {
        checkboxes = {
          " " = {
            char = "󰄱";
            hl_group = "ObsidianTodo";
          };
          x = {
            char = "✔";
            hl_group = "ObsidianDone";
          };
        };
      };
      note_id_func = ''
        function(title)
          local suffix = ""
          if title ~= nil then
            suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
          else
            for _ = 1, 4 do
              suffix = suffix .. string.char(math.random(65, 90))
            end
          end
          return tostring(os.time()) .. "-" .. suffix
        end'';
    };
  };
  opts.conceallevel = 1;
  keymaps = [
    {
      key = "<Leader>on";
      action = '':ObsidianNew<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}
