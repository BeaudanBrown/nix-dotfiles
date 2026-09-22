{ pkgs }:

pkgs.buildGoModule {
  pname = "tmux_project";
  version = "0.1.0";

  src = ./tmux-project-go;
  vendorHash = null;

  nativeBuildInputs = [ pkgs.makeWrapper ];
  nativeCheckInputs = [ pkgs.git ];

  postInstall = ''
    # Both the launcher and plugin subprocesses use this entrypoint. Pin the
    # config even when a boot service has no XDG_CONFIG_HOME. -f only affects
    # server creation; attaching never reloads a live server's configuration.
    mkdir -p $out/libexec
    cat > $out/libexec/tmux <<'EOF'
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.tmux}/bin/tmux -f "''${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" "$@"
    EOF
    chmod +x $out/libexec/tmux
    wrapProgram $out/libexec/tmux \
      --prefix PATH : "$out/bin:$out/libexec:${
        pkgs.lib.makeBinPath (import ./tmux-runtime.nix { inherit pkgs; })
      }"
    wrapProgram $out/bin/tmux-project \
      --prefix PATH : "$out/bin:$out/libexec:${
        pkgs.lib.makeBinPath (import ./tmux-runtime.nix { inherit pkgs; })
      }"
    mv $out/bin/tmux-project $out/bin/tmux_project
  '';
}
