{ pkgs }:
pkgs.writeShellApplication {
  name = "dump-publish";
  runtimeInputs = [
    pkgs.python3
    pkgs.hugo
  ];
  text = ''
    exec python3 ${./publish.py} "$@"
  '';
}
