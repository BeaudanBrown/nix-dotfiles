#!/usr/bin/env bash
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
	cp "$FL_R_FLAKE" ./flake.nix
	cp "$FL_R_ENVRC" ./.envrc
	cp "$FL_R_LINTR" ./.lintr
	cp "$FL_R_GITIGNORE" ./.gitignore
	chmod 644 ./.gitignore ./.lintr ./flake.nix ./.envrc
	git add ./.gitignore ./flake.nix ./.envrc
	;;
"go")
	echo "Setting up Go environment..."
	cp "$FL_GO_FLAKE" ./flake.nix
	cp "$FL_GO_ENVRC" ./.envrc
	cp "$FL_GO_GITIGNORE" ./.gitignore
	chmod 644 ./.gitignore ./flake.nix ./.envrc
	git add ./.gitignore ./flake.nix ./.envrc
	;;
"py")
	echo "Setting up Python environment..."
	cp "$FL_PY_FLAKE" ./flake.nix
	cp "$FL_PY_ENVRC" ./.envrc
	cp "$FL_PY_GITIGNORE" ./.gitignore
	chmod 644 ./.gitignore ./flake.nix ./.envrc
	git add ./.gitignore ./flake.nix ./.envrc
	;;
*)
	print_usage
	exit 1
	;;
esac
