{ pkgs }:

pkgs.buildGoModule {
  pname = "tmux_project";
  version = "0.1.0";

  src = ./tmux-project-go;
  vendorHash = null;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/tmux-project \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.fd
          pkgs.fzf
          pkgs.git
          pkgs.tmux
          pkgs.autojump
        ]
      }
    mv $out/bin/tmux-project $out/bin/tmux_project
  '';
}
