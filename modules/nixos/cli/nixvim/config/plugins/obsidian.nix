{...}:
{
  plugins.obsidian = {
    enable = true;
    settings = {
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
      mappings = {
        "<localleader><localleader>" = {
          action = "require('obsidian').util.toggle_checkbox";
          opts = {
            buffer = true;
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
  opts.conceallevel = 2;
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
    {
      key = "<cr>";
      action = ''require("obsidian").util.smart_action()'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
        buffer = true;
      };
    }
  ];
}

