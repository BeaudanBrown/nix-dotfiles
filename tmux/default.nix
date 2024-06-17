{ lib, pkgs, ... }:
let
  plugins = pkgs.tmuxPlugins // pkgs.callPackage ./custom-plugins.nix { };
in
{
  programs.tmux = {
    enable = true;
    escapeTime = 0;
    historyLimit = 50000;
    keyMode = "vi";
    terminal = "tmux-256color";
    plugins = with plugins; [
      catppuccin
      extrakto
      select-pane-no-wrap
    ];
    extraConfig = ''
set-option -g prefix C-b
bind-key C-b send-prefix
bind-key -n M-n select-window -n
bind-key -n M-p select-window -p

bind -r v split-window -h -p 50 -c '#{pane_current_path}' # horizontally split active pane
bind -r s split-window -v -p 50 -c '#{pane_current_path}' # vertically split active pane
bind -r V split-window -fh -c '#{pane_current_path}' # horizontal for whole screen
bind -r S split-window -fv -c '#{pane_current_path}' # vertical for whole screen
set-option -g status-position top # put the status bar at the top

set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on
set -g mouse on
bind-key -n C-Space resize-pane -Z # C-space to zoom pane

is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"

bind -n M-h if-shell "$is_vim" "send-keys M-h" "run '#{select_pane_no_wrap} L'"
bind -n M-j if-shell "$is_vim" "send-keys M-j" "run '#{select_pane_no_wrap} D'"
bind -n M-k if-shell "$is_vim" "send-keys M-k" "run '#{select_pane_no_wrap} U'"
bind -n M-l if-shell "$is_vim" "send-keys M-l" "run '#{select_pane_no_wrap} R'"
    '';
  };

}
