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
      app-notifications = "no-clipboard-copy";
      clipboard-read = "allow";
      clipboard-write = "allow";
      clipboard-paste-protection = false;
      copy-on-select = "clipboard";
      custom-shader = "${./cursor-tail-rounded.glsl}";
    };
  };
}
