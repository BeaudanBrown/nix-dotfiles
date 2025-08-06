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
      rev = "9a75967ced4f3925de0714e96395223aa7e2b4ad";
      sha256 = "sha256-klS3MoGQnEiUa9RldKGn7D9yxw/9OXbfww43Wi1lV/w=";
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
      set -g @tmux_window_name_icon_style "'name_and_icon'"
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
