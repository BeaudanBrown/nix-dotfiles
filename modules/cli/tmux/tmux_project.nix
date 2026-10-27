{ pkgs }:

# Exact focus needs tmux 3.6; progressive reload is tested against fzf's 0.70 API.
# Fail at package evaluation rather than silently shipping an incompatible UI.
assert pkgs.lib.versionAtLeast pkgs.tmux.version "3.6";
assert pkgs.lib.versionAtLeast pkgs.fzf.version "0.70";
pkgs.buildGoModule {
  pname = "tmux_project";
  version = "0.1.0";

  src = ./tmux-project-go;
  vendorHash = null;

  nativeBuildInputs = [ pkgs.makeWrapper ];
  # Tests use explicit disposable sockets. Avoid the shared-server wrapper even
  # during future, separately authorized package checks.
  nativeCheckInputs = [
    pkgs.git
    (pkgs.tmux.rawTmux or pkgs.tmux)
    pkgs.fzf
    pkgs.fd
    pkgs.python3
  ];
  PI_TEST_FZF = "${pkgs.fzf}/bin/fzf";
  # Keep real terminal/process test execution and any skips visible in build logs.
  checkFlags = [ "-v" ];

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
