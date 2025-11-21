{ pkgs, ... }:
{
  hm.programs.fzf = {
    enable = true;
    enableZshIntegration = true;

    # Use fd for file and directory search (respects .gitignore by default)
    defaultCommand = "${pkgs.fd}/bin/fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "${pkgs.fd}/bin/fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d --hidden --follow --exclude .git";

    # Default options for all fzf invocations
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border=none"
    ];

    # Options for Ctrl+T (file widget)
    fileWidgetOptions = [
      "--prompt=GIT> "
      "--header=CTRL-G: toggle gitignore"
      "--bind=ctrl-g:reload(fd --type f --hidden --follow --exclude .git --no-ignore)+change-prompt(ALL> )+change-header(CTRL-G: toggle gitignore)"
    ];

    # Options for Alt+C (change directory widget)
    changeDirWidgetOptions = [
      "--prompt=GIT> "
      "--header=CTRL-G: toggle gitignore"
      "--bind=ctrl-g:reload(fd --type d --hidden --follow --exclude .git --no-ignore)+change-prompt(ALL> )+change-header(CTRL-G: toggle gitignore)"
    ];
  };

  # Ensure fd is available
  hm.home.packages = [ pkgs.fd ];
}
