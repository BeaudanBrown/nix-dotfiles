{ ... }:
{
  # pi4: purple theme (#9b59b6)
  hm.primary.programs.starship.settings = {
    username = {
      style_user = "fg:#9b59b6";
      format = "[$user]($style)[@](fg:#9b59b6)";
    };
    hostname.style = "fg:#9b59b6";
    character = {
      success_symbol = "[❯](bold #9b59b6)";
      error_symbol = "[❯](bold red)";
      # vimcmd_symbol causes delays in tmux popups due to vi-mode detection
      # vimcmd_symbol = "[❮](bold #9b59b6)";
    };
  };
}
