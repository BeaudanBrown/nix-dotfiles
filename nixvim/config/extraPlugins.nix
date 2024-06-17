{ pkgs, lib, ...}:
let
  customPlugins = {
    replace-with-register = pkgs.vimUtils.buildVimPlugin {
      name = "replace-with-register";
      src = pkgs.fetchFromGitHub {
        owner = "inkarkat";
        repo = "vim-ReplaceWithRegister";
        rev = "aad1e8fa31cb4722f20fe40679caa56e25120032";
        hash = "sha256-9dGcOFmbkBwVvPdqP30V3IzDZ5BKLdFLuYtXXXCPz7E=";
      };
    };
    textobj-user = pkgs.vimUtils.buildVimPlugin {
      name = "textobj-user";
      src = pkgs.fetchFromGitHub {
        owner = "kana";

        repo = "vim-textobj-user";
        rev = "41a675ddbeefd6a93664a4dc52f302fe3086a933";
        hash = "sha256-4+9SlywaEKpJL6MM2jcBjFoy2dpLqviil9idVNkeL/g=";
      };
    };
    textobj-entire = pkgs.vimUtils.buildVimPlugin {
      name = "textobj-entire";
      src = pkgs.fetchFromGitHub {
        owner = "kana";
        repo = "vim-textobj-entire";
        rev = "64a856c9dff3425ed8a863b9ec0a21dbaee6fb3a";
        hash = "sha256-te7ljHY7lzu+fmbakTkPKxF312+Q0LozTLazxQvSYE8=";
      };
    };
    cmp-r = pkgs.vimUtils.buildVimPlugin {
      name = "cmp-r";
      src = pkgs.fetchFromGitHub {
        owner = "R-nvim";
        repo = "cmp-r";
        rev = "efa34e762dea378cae27a9e47bdd95afb0bc8dfc";
        hash = "sha256-XVs/1Z96amWrT7us0hgzBmEXoofBUBqm+TYUX3aqLmI=";
      };
    };
    vim-ai = pkgs.vimUtils.buildVimPlugin {
      name = "vim-ai";
      src = pkgs.fetchFromGitHub {
        owner = "madox2";
        repo = "vim-ai";
        rev = "56dc5a54b118727881d225087ff3a20e5b0f6c79";
        hash = "sha256-OMdgWMPrq89CQekeUteoDQvrNBOGchxv9qEaEpRx0w8=";
      };
    };
    r-nvim = pkgs.vimUtils.buildVimPlugin {
      name = "r-nvim";
      src = pkgs.fetchFromGitHub {
        owner = "R-nvim";
        repo = "r.nvim";
        rev = "964075526267bf5768d14b6be83bea7a17ada56f";
        hash = "sha256-lgusti4dehig3+4Z/SadzfrErFHzDNGrXs69NLAHwKA=";
      };
    };
    highlighted-yank = pkgs.vimUtils.buildVimPlugin {
      name = "highlighted-yank";
      src = pkgs.fetchFromGitHub {
        owner = "machakann";
        repo = "vim-highlightedyank";
        rev = "afb0f262b490706c23e94012c2ab9fa67c0481ce";
        hash = "sha256-WcSxpXYErKyr/9LaAmFw6WfpcKq2YlbLag6HVVhwyFQ=";
      };
    };
  };
in
  {
    extraPlugins = builtins.map (name: { plugin = customPlugins.${name}; }) (lib.attrNames customPlugins);
  }
