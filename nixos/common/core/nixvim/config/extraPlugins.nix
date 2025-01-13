{ pkgs, ...}:
{
  extraPlugins = [
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
        name = "vim-ai";
        src = pkgs.fetchFromGitHub {
          owner = "madox2";
          repo = "vim-ai";
          rev = "380d5cdd9538c2522dfc8d03a8a261760bb0439a";
          hash = "sha256-ywnBM2YBysrs5EF0lpxKH0cYXJZvFgL+F9f+kCuiFJ8=";
        };
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
  ];
}
