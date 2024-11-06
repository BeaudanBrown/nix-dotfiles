{ pkgs, lib, ...}:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "quarto-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "quarto-dev";
          repo = "quarto-nvim";
          rev = "23083a0152799ca7263ac9ae53d768d4dd93d24e";
          hash = "sha256-JeRiyEPpCrFaNhlrS+CH8j2Sv8c9BnL8XoSG9aTnVVU=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "replace-with-register";
        src = pkgs.fetchFromGitHub {
          owner = "inkarkat";
          repo = "vim-ReplaceWithRegister";
          rev = "aad1e8fa31cb4722f20fe40679caa56e25120032";
          hash = "sha256-9dGcOFmbkBwVvPdqP30V3IzDZ5BKLdFLuYtXXXCPz7E=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "yazi-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "mikavilpas";
          repo = "yazi.nvim";
          rev = "65bff77e59e0b5c8587266580c24d658913b825e";
          hash = "sha256-NTblfvfw1i8SsqCNxMRwRsesYlrckfYnSpWW1E3pj1I=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "textobj-user";
        src = pkgs.fetchFromGitHub {
          owner = "kana";
          repo = "vim-textobj-user";
          rev = "41a675ddbeefd6a93664a4dc52f302fe3086a933";
          hash = "sha256-4+9SlywaEKpJL6MM2jcBjFoy2dpLqviil9idVNkeL/g=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "textobj-entire";
        src = pkgs.fetchFromGitHub {
          owner = "kana";
          repo = "vim-textobj-entire";
          rev = "64a856c9dff3425ed8a863b9ec0a21dbaee6fb3a";
          hash = "sha256-te7ljHY7lzu+fmbakTkPKxF312+Q0LozTLazxQvSYE8=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "cmp-r";
        src = pkgs.fetchFromGitHub {
          owner = "R-nvim";
          repo = "cmp-r";
          rev = "efa34e762dea378cae27a9e47bdd95afb0bc8dfc";
          hash = "sha256-XVs/1Z96amWrT7us0hgzBmEXoofBUBqm+TYUX3aqLmI=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "vim-ai";
        src = pkgs.fetchFromGitHub {
          owner = "madox2";
          repo = "vim-ai";
          rev = "af4ec9cde483eb68f4b48b41a6c70a02235051bb";
          hash = "sha256-o0710Mb+SIOJtsTbog+JzgeW8rveISTUn3vk4mHmVGg=";
        };
      # TODO: Figure out how to set my config option
      # or at the very least just make it so that when you use o1 models it
      # doesn't use a system prompt
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "r-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "R-nvim";
          repo = "r.nvim";
          rev = "964075526267bf5768d14b6be83bea7a17ada56f";
          hash = "sha256-lgusti4dehig3+4Z/SadzfrErFHzDNGrXs69NLAHwKA=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "highlighted-yank";
        src = pkgs.fetchFromGitHub {
          owner = "machakann";
          repo = "vim-highlightedyank";
          rev = "afb0f262b490706c23e94012c2ab9fa67c0481ce";
          hash = "sha256-WcSxpXYErKyr/9LaAmFw6WfpcKq2YlbLag6HVVhwyFQ=";
        };
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "plenary-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "nvim-lua";
          repo = "plenary.nvim";
          rev = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683";
          hash = "sha256-5Jf2mWFVDofXBcXLbMa417mqlEPWLA+cQIZH/vNEV1g=";
        };
      };
    }
  ];
}
