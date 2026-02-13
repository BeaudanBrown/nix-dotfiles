{ ... }:
{
  # nas: green theme (#2ecc71)
  hm.primary.programs.starship.settings = {
    username = {
      style_user = "fg:#2ecc71";
      format = "[$user]($style)[@](fg:#2ecc71)";
    };
    hostname.style = "fg:#2ecc71";
    character = {
      success_symbol = "[❯](bold #2ecc71)";
      error_symbol = "[❯](bold red)";
      # vimcmd_symbol causes delays in tmux popups due to vi-mode detection
      # vimcmd_symbol = "[❮](bold #2ecc71)";
    };
  };
}
