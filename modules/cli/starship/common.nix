{ lib, ... }:
{
  hm.programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # Overall format matching oh-my-posh layout
      # Note: username/hostname colors and @ sign are set per-host
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "[: ](fg:blue)"
        "$directory"
        "$git_branch"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      # Add a newline before the prompt (matches oh-my-posh "newline": true)
      add_newline = true;

      # Username (always shown) - color set per-host
      username = {
        show_always = true;
        # style_user will be overridden per-host
      };

      # Hostname (always shown) - color set per-host
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style)";
        # style will be overridden per-host
      };

      # Directory (full path like oh-my-posh "style": "full")
      directory = {
        format = "[$path]($style)";
        style = "fg:blue";
        truncation_length = 0;
        truncate_to_repo = false;
      };

      # Git branch (dimmed white, no icon)
      git_branch = {
        format = " [$branch]($style)";
        style = "fg:white dimmed";
        symbol = "";
      };

      # Git status (shows * if working/staging changed, ⇣⇡ for behind/ahead)
      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style))";
        style = "fg:white dimmed";
        # Show * for any changes
        modified = "*";
        staged = "*";
        # Arrows for ahead/behind
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇡⇣";
        # Hide other status indicators to match oh-my-posh
        conflicted = "";
        deleted = "";
        renamed = "";
        stashed = "";
        untracked = "";
      };

      # Command execution time (shown inline, like rprompt)
      cmd_duration = {
        min_time = 5000; # 5 seconds threshold
        format = " [$duration]($style)";
        style = "fg:yellow";
        show_milliseconds = true;
      };
    };
  };
}
