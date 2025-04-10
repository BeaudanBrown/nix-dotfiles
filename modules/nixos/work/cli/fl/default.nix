{ pkgs, ... }:
let
  script = ''
  print_usage() {
    echo "Usage: $0 [r|go]"
    echo "  r  - Set up R environment"
    echo "  go - Set up Go environment"
    echo "  py - Set up Python environment"
  }

  if [ -z "$1" ]; then
    print_usage
    exit 1
  fi

  case "$1" in
    "r")
      echo "Setting up R environment..."
      cp ${./r/flake.nix} ./flake.nix
      cp ${./r/envrc} ./.envrc
      cp ${./r/lintr} ./.lintr
      cp ${./r/gitignore} ./.gitignore
      chmod 644 ./.gitignore ./.lintr ./flake.nix ./.envrc
      git add ./.gitignore ./flake.nix ./.envrc
      ;;
    "go")
      echo "Setting up Go environment..."
      cp ${./go/flake.nix} ./flake.nix
      cp ${./go/envrc} ./.envrc
      cp ${./go/gitignore} ./.gitignore
      chmod 644 ./.gitignore ./flake.nix ./.envrc
      git add ./.gitignore ./flake.nix ./.envrc
      ;;
    "py")
      echo "Setting up Python environment..."
      cp ${./python/flake.nix} ./flake.nix
      cp ${./python/envrc} ./.envrc
      cp ${./python/gitignore} ./.gitignore
      chmod 644 ./.gitignore ./flake.nix ./.envrc
      git add ./.gitignore ./flake.nix ./.envrc
      ;;
    *)
      print_usage
      exit 1
      ;;
      esac
  '';

in
  {
    environment.systemPackages = with pkgs; [
      (writeShellApplication {
        name = "fl";
        text = script;
      })
    ];
  }
