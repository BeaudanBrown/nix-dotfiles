{ pkgs, ... }:
{
  extraPlugins = [
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
  ];
}
