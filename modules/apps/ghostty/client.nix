{ ... }:
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
      custom-shader = "${./cursor-tail-rounded.glsl}";
    };
  };
}
