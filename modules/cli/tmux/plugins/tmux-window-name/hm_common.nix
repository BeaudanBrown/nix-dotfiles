{ pkgs, lib, ... }:
let
  pythonInputs = (
    pkgs.python3.withPackages (
      p: with p; [
        libtmux
        pip
      ]
    )
  );
  tmux-window-name = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-window-name";
    version = "2024-03-08";
    src = pkgs.fetchFromGitHub {
      owner = "ofirgall";
      repo = "tmux-window-name";
      rev = "dc97a79ac35a9db67af558bb66b3a7ad41c924e7";
      sha256 = "sha256-o7ZzlXwzvbrZf/Uv0jHM+FiHjmBO0mI63pjeJwVJEhE=";
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    rtpFilePath = "tmux_window_name.tmux";
    postInstall = ''
      for f in tmux_window_name.tmux scripts/rename_session_windows.py; do
        wrapProgram $target/$f \
          --prefix PATH : ${lib.makeBinPath [ pythonInputs ]}
      done
    '';
  };
in
{
  programs.tmux.extraConfig = # bash
    ''
      set -g @tmux_window_dir_programs "['nvim', 'vim', 'vi', 'git']"
    '';

  programs.zsh.initContent = ''
    tmux-window-name() {
      (${builtins.toString tmux-window-name}/share/tmux-plugins/tmux-window-name/scripts/rename_session_windows.py &)
    }
    if [[ -n "$TMUX" ]]; then
      add-zsh-hook chpwd tmux-window-name
    fi
  '';

  programs.tmux.plugins = [
    tmux-window-name
  ];
}
