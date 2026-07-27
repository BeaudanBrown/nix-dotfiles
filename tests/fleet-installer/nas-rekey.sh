#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export SOPS_AGE_KEY_FILE="$tmp/age-key.txt"
age-keygen -o "$SOPS_AGE_KEY_FILE" 2>"$tmp/age-output"
public_key=$(awk '/Public key:/ { print $3 }' "$tmp/age-output")

mkdir -p "$tmp/remote.git"
git init --bare --quiet "$tmp/remote.git"
git init --quiet -b main "$tmp/sops-secrets"
git -C "$tmp/sops-secrets" config user.name "Installer Test"
git -C "$tmp/sops-secrets" config user.email "installer@example.invalid"
git -C "$tmp/sops-secrets" remote add origin "$tmp/remote.git"
mkdir -p "$tmp/sops-secrets/secrets"
cat >"$tmp/sops-secrets/.sops.yaml" <<EOF
keys:
  - &master $public_key
creation_rules:
  - path_regex: secrets/.*\\.yaml$
    key_groups:
      - age:
          - *master
EOF
printf 'fixture: value\n' >"$tmp/plain.yaml"
sops --config "$tmp/sops-secrets/.sops.yaml" --encrypt "$tmp/plain.yaml" >"$tmp/sops-secrets/secrets/work.yaml"
git -C "$tmp/sops-secrets" add .
git -C "$tmp/sops-secrets" commit --quiet -m initial
git -C "$tmp/sops-secrets" push --quiet -u origin main

request=$(jq -n \
	--arg host installer-test \
	--rawfile yaml "$tmp/sops-secrets/.sops.yaml" \
	'{targetHost: $host, sopsYamlBase64: ($yaml | @base64)}')
response=$(printf '%s' "$request" |
	FLEET_INSTALLER_TEST=1 \
		FLEET_INSTALLER_SOPS_REPO="$tmp/sops-secrets" \
		"$repo_root/result/bin/fleet-installer" nas-rekey)

commit=$(jq -er '.commit' <<<"$response")
test "$commit" = "$(git --git-dir="$tmp/remote.git" rev-parse refs/heads/main)"
git --git-dir="$tmp/remote.git" log -1 --format=%s | grep -qx 'Rekey secrets for installer-test'
