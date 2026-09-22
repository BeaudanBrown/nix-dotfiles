{ pkgs }:
# Commands used by tmux plugins and config hooks, including env-based shebangs.
# Keep this independent of the login shell and the managed relay's PATH.
with pkgs;
[
  bash
  coreutils
  findutils
  gnugrep
  gnused
  gawk
  procps
  python3
  fd
  fzf
  git
  autojump
]
