{ ... }:
{
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
    backspace = [
      "indent"
      "eol"
      "start"
    ];
    undodir.__raw = ''(os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/undodir/"'';
    directory.__raw = ''(os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/swp/"'';
  };
}
