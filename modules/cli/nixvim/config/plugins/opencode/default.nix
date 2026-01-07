{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "opencode-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "NickvanDyke";
          repo = "opencode.nvim";
          rev = "dfca5bb214d78a600781d50da350238b3e6e2621";
          hash = "sha256-W7fPGiLpKRe1Nw0MckigUijTNq+L9Z+vxOKcf3oNZf0=";
        };
      };
    }
  ];

  extraConfigLua = ''
    vim.g.opencode_opts = {
      auto_reload = true,
      -- Define custom prompts
      prompts = {
        explain = { prompt = "Explain @this and its context" },
      },
    }'';
  # plugins.opencode = {
  #   enable = true;
  #   settings = {
  #     # port = 17862;
  #     provider = {
  #       enabled = "tmux";
  #     };
  #     # provider = {
  #     #   toggle.__raw = ''function(self) local cwd = vim.fn.getcwd(); local name = "opencode_" .. vim.fn.fnamemodify(cwd, ":t"); local cmd = "opencode --port 17862"; vim.fn.system("tmux_toggle_popup -C " .. vim.fn.shellescape(cwd) .. " " .. name .. " " .. vim.fn.shellescape(cmd)) end'';
  #     #   start.__raw = ''function(self) local cwd = vim.fn.getcwd(); local name = "opencode_" .. vim.fn.fnamemodify(cwd, ":t"); local cmd = "opencode --port 17862"; vim.fn.system("tmux_toggle_popup -C " .. vim.fn.shellescape(cwd) .. " " .. name .. " " .. vim.fn.shellescape(cmd)); vim.wait(2500) end'';
  #     #   stop.__raw = ''function(self) local cwd = vim.fn.getcwd(); local name = "opencode_" .. vim.fn.fnamemodify(cwd, ":t"); vim.fn.system("tmux kill-session -t " .. name) end'';
  #     # };
  #   };
  # };
}
