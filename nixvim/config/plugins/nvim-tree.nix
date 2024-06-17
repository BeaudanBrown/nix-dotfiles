{
  plugins.nvim-tree = {
    enable = true;
    disableNetrw = true;
    openOnSetup = true;
    actions.openFile.quitOnOpen = true;
    # view.float.enable = true;
  };
  keymaps = [
    {
      key = "<leader>e";
      action = ''<cmd>NvimTreeOpen<CR>'';
      mode = [ "n" ];
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}
