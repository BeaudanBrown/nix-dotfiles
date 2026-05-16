{ pkgs, ... }:
let
  cursorShaders = pkgs.fetchFromGitHub {
    owner = "sahaj-b";
    repo = "ghostty-cursor-shaders";
    rev = "4faa83e4b9306750fc8de64b38c6f53c57862db8";
    hash = "sha256-ruhEqXnWRCYdX5mRczpY3rj1DTdxyY3BoN9pdlDOKrE=";
  };
in
{
  environment.sessionVariables = {
    TERMINAL = "ghostty";
  };

  hm.primary.programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      confirm-close-surface = false;
      bell-features = "no-audio";
      clipboard-write = "allow";
      copy-on-select = "clipboard";
      custom-shader = "${cursorShaders}/cursor_tail.glsl";
    };
  };
}
