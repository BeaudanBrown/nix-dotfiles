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
printf 'fixture: value\n' >"$tmp/sops-secrets/secrets/work.yaml"
printf 'legacy: value\n' >"$tmp/sops-secrets/secrets/rozzy.yaml"
printf 'public: metadata\n' >"$tmp/sops-secrets/secrets/bottom.yaml"
(
	cd "$tmp/sops-secrets"
	sops --encrypt --in-place secrets/work.yaml
	sops --encrypt --in-place secrets/rozzy.yaml
)
git -C "$tmp/sops-secrets" add .
git -C "$tmp/sops-secrets" commit --quiet -m initial
git -C "$tmp/sops-secrets" push --quiet -u origin main
legacy_blob=$(git --git-dir="$tmp/remote.git" rev-parse refs/heads/main:secrets/rozzy.yaml)

age-keygen -o "$tmp/new-age-key.txt" 2>"$tmp/new-age-output"
new_public_key=$(awk '/Public key:/ { print $3 }' "$tmp/new-age-output")
cat >"$tmp/new-sops.yaml" <<EOF
keys:
  - &master $new_public_key
creation_rules:
  - path_regex: secrets/work\\.yaml$
    key_groups:
      - age:
          - *master
EOF
request=$(jq -n \
	--arg host installer-test \
	--rawfile yaml "$tmp/new-sops.yaml" \
	'{targetHost: $host, sopsYamlBase64: ($yaml | @base64)}')
response=$(printf '%s' "$request" |
	FLEET_INSTALLER_TEST=1 \
		FLEET_INSTALLER_SOPS_REPO="$tmp/sops-secrets" \
		"$repo_root/result/bin/fleet-installer" nas-rekey)

commit=$(jq -er '.commit' <<<"$response")
test "$commit" = "$(git --git-dir="$tmp/remote.git" rev-parse refs/heads/main)"
git --git-dir="$tmp/remote.git" log -1 --format=%s refs/heads/main | grep -qx 'Rekey secrets for installer-test'
test "$(git --git-dir="$tmp/remote.git" show refs/heads/main:secrets/bottom.yaml)" = 'public: metadata'
test "$(git --git-dir="$tmp/remote.git" rev-parse refs/heads/main:secrets/rozzy.yaml)" = "$legacy_blob"
