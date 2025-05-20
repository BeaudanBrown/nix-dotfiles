{ pkgs, osConfig, ... }:
let
  new_gpt_chat = import ./new_gpt_chat.nix { inherit pkgs; };
  tmux_toggle_popup = import ./tmux_toggle_popup.nix { inherit pkgs; };
in
{
  programs.tmux = {
    enable = true;
    escapeTime = 0;
    historyLimit = 50000;
    keyMode = "vi";
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      catppuccin
      extrakto
      yank
    ];
    extraConfig = # bash
      ''
          set-option -g prefix C-Space
          bind-key C-Space send-prefix
          unbind C-r
          bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"
          bind-key -n M-n select-window -n
          bind-key -n M-p select-window -p
          bind C-u copy-mode -u

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
          bind-key C-Space resize-pane -Z # C-space to zoom pane

          is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
              | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
          bind-key -n 'M-h' if-shell "$is_vim" { send-keys M-h } { if-shell -F '#{pane_at_left}'   {} { select-pane -L } }
          bind-key -n 'M-j' if-shell "$is_vim" { send-keys M-j } { if-shell -F '#{pane_at_bottom}' {} { select-pane -D } }
          bind-key -n 'M-k' if-shell "$is_vim" { send-keys M-k } { if-shell -F '#{pane_at_top}'    {} { select-pane -U } }
          bind-key -n 'M-l' if-shell "$is_vim" { send-keys M-l } { if-shell -F '#{pane_at_right}'  {} { select-pane -R } }

          bind-key -T copy-mode-vi 'M-h' if-shell -F '#{pane_at_left}'   {} { select-pane -L }
          bind-key -T copy-mode-vi 'M-j' if-shell -F '#{pane_at_bottom}' {} { select-pane -D }
          bind-key -T copy-mode-vi 'M-k' if-shell -F '#{pane_at_top}'    {} { select-pane -U }
          bind-key -T copy-mode-vi 'M-l' if-shell -F '#{pane_at_right}'  {} { select-pane -R }


        # Toggle scratchpad terminal

          set -gF '@last_scratch_name' scratch

          bind-key -n M-Space if-shell -F '#{==:#{session_name},default}' {
            run-shell 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s #{@last_scratch_name} "'
          } {
            detach-client
          }

          bind-key -n M-Enter run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup scratch"

          bind-key -n M-b run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup -w build"

          rebuild_cmd="zsh -c \\\"nh os switch ${osConfig.hostSpec.dotfiles}\\\"; exec zsh"
          bind-key -n M-r \
                run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup rebuild \"$rebuild_cmd\""

          bind-key -n M-R \
                run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup -f rebuild \"$rebuild_cmd\""

          bind-key -n M-m run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup -w gpt ${new_gpt_chat}/bin/new_gpt_chat"

          bind-key -n M-M run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup -w codex \"direnv allow .; eval $(direnv export bash); codex\""

          bind-key -n M-o run-shell "${tmux_toggle_popup}/bin/tmux_toggle_popup obsidian \"mkdir -p ~/documents/vault/main && cd ~/documents/vault/main && nvim -O ~/documents/vault/main/triage.md\""

          bind -n M-\\ if-shell -F '#{==:#{session_name},#{@last_scratch_name}}' {
            run-shell 'tmux break-pane -s "#{@last_scratch_name}" -t default'
            detach-client
          } {
            if-shell '! tmux has-session -t "#{@last_scratch_name}"' {
              run-shell 'tmux new-session -d -s #{@last_scratch_name}'
            }
            run-shell 'tmux break-pane -t "#{@last_scratch_name}"'
            run-shell 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s #{@last_scratch_name} "'
          }

          bind -n M-| if-shell -F '#{==:#{session_name},#{@last_scratch_name}}' {
            run-shell 'tmux join-pane -h -s "#{@last_scratch_name}" -t default:$(tmux display-message -p -t default "#{l:#{window_index}}")'
            if-shell 'tmux has-session -t "#{@last_scratch_name}"' {
              detach-client
            }
          } {
            if-shell '! tmux has-session -t "#{@last_scratch_name}"' {
              run-shell 'tmux new-session -d -s #{@last_scratch_name}'
            }
            run-shell 'tmux break-pane -s "#S:#I.#P" -t "#{@last_scratch_name}"'
            run-shell 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s #{@last_scratch_name} "'
          }
      '';
  };
}
