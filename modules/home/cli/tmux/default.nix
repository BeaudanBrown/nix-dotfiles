{
  lib,
  pkgs,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.tmux;
  plugins = pkgs.tmuxPlugins // pkgs.callPackage ./custom-plugins.nix { };
in {
  options.${namespace}.cli.tmux = {
    enable = mkBoolOpt false "Whether to enable tmux configuration.";
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      escapeTime = 0;
      historyLimit = 50000;
      keyMode = "vi";
      terminal = "tmux-256color";
      plugins = with plugins; [
        catppuccin
        extrakto
        yank
      ];
      extraConfig = ''
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

  bind-key -n M-Enter if-shell -F '#{==:#{session_name},scratch}' {
    set -gF '@last_scratch_name' scratch
    detach-client
  } {
    set -gF '@last_scratch_name' scratch
    if-shell -F '#{!=:#{session_name},default}' {
      detach-client
    }
    run-shell -t default: 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s scratch -c #{pane_current_path}"'
  }

  bind-key -n M-b if-shell -F '#{==:#{session_name},build}' {
    set -gF '@last_scratch_name' build
    detach-client
  } {
    set -gF '@last_scratch_name' build
    if-shell -F '#{!=:#{session_name},default}' {
      detach-client
    }
    run-shell -t default: 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s build -c #{pane_current_path}"'
  }

  bind-key -n M-R if-shell -F '#{==:#{session_name},rebuild}' {
    set -gF '@last_scratch_name' rebuild
    send-keys -t rebuild: 'sudo nixos-rebuild switch' C-m
  } {
    set -gF '@last_scratch_name' rebuild
    if-shell -F '#{!=:#{session_name},default}' {
      detach-client
    }
    if-shell 'tmux has-session -t rebuild' {
      send-keys -t rebuild: 'sudo nixos-rebuild switch' C-m
    }
    run-shell -t default: 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s rebuild \"zsh -c \\\"sudo nixos-rebuild switch; exec zsh \\\"\""'
  }

  bind-key -n M-r if-shell -F '#{==:#{session_name},rebuild}' {
    set -gF '@last_scratch_name' rebuild
    detach-client
  } {
    set -gF '@last_scratch_name' rebuild
    if-shell -F '#{!=:#{session_name},default}' {
      detach-client
    }
    run-shell -t default: 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s rebuild \"zsh -c \\\"sudo nixos-rebuild switch; exec zsh \\\"\""'
  }

  bind-key -n M-m if-shell -F '#{==:#{session_name},gpt}' {
    set -gF '@last_scratch_name' gpt
    detach-client
  } {
    set -gF '@last_scratch_name' gpt
    if-shell -F '#{!=:#{session_name},default}' {
      detach-client
    }
    run-shell -t default: 'tmux display-popup -E -w 95% -h 95% "tmux new-session -A -s gpt \"${pkgs.dotfiles.new_gpt_chat}/bin/new_gpt_chat\""'
  }

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
  };
}
