#!/usr/bin/env bash
set -euo pipefail

# Script to generate .sops.yaml from centralized hostSpecs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if .sops.yaml already exists
if [[ -f .sops.yaml ]]; then
	echo "⚠️  .sops.yaml already exists. Skipping generation."
	echo "To regenerate, delete .sops.yaml first."
	exit 0
fi

echo "Generating .sops.yaml from hostSpecs..."

# Use nix eval to get the config structure as JSON
# Fix: Use flake's nixpkgs instead of <nixpkgs> to avoid NIX_PATH dependency
CONFIG_JSON=$(nix eval --json --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    lib = flake.inputs.nixpkgs.lib;
    genSopsYaml = import ./lib/gen-sops-yaml.nix { inherit lib; };
  in
    genSopsYaml
')

# Parse and build YAML manually for proper formatting
# Extract keys
KEYS=$(echo "$CONFIG_JSON" | jq -r '.keys[] | to_entries[] | "&\(.key) \(.value)"')

# Start building YAML
{
	echo "keys:"
	echo "$KEYS" | while IFS= read -r line; do
		echo "  - $line"
	done
	echo ""
	echo "creation_rules:"

	# Extract creation rules
	RULES_COUNT=$(echo "$CONFIG_JSON" | jq '.creation_rules | length')
	for ((i = 0; i < RULES_COUNT; i++)); do
		PATH_REGEX=$(echo "$CONFIG_JSON" | jq -r ".creation_rules[$i].path_regex")
		AGE_KEYS=$(echo "$CONFIG_JSON" | jq -r ".creation_rules[$i].key_groups[0].age | map(\"*\" + .) | join(\", \")")

		echo "  - path_regex: $PATH_REGEX"
		echo "    key_groups:"
		echo "      - age:"
		echo "$AGE_KEYS" | tr ',' '\n' | sed 's/^[[:space:]]*\*/          - */' | sed 's/[[:space:]]*$//'
	done
} >.sops.yaml

echo "✓ Generated .sops.yaml"
