{ pkgs, rawTmux }:
pkgs.symlinkJoin {
  name = "tmux-shared-client-${rawTmux.version}";
  paths = [
    rawTmux
    rawTmux.man
  ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    rm "$out/bin/tmux"
    cat > "$out/bin/tmux" <<'EOF'
    #!${pkgs.bash}/bin/bash
    raw_tmux=${rawTmux}/bin/tmux
    ${builtins.readFile ./shared-client.sh}
    EOF
    chmod +x "$out/bin/tmux"
    wrapProgram "$out/bin/tmux" --prefix PATH : ${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
      ]
    }
  '';
  passthru = {
    inherit rawTmux;
    inherit (rawTmux) version;
  };
  meta = rawTmux.meta // {
    outputsToInstall = [ "out" ];
  };
}
