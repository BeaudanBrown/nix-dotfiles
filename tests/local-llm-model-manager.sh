#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manager="$repository_root/modules/services/local-llm/model-manager.sh"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

source_model="$temporary/source.gguf"
printf 'tiny deterministic model fixture\n' >"$source_model"
sha256=$(sha256sum "$source_model" | cut -d' ' -f1)
size=$(stat -c %s "$source_model")
owner=$(id -un)
group=$(id -gn)
export LOCAL_LLM_MODEL_DIRECTORY="$temporary/models"
export LOCAL_LLM_MODEL_REPOSITORY="fixture/model"
export LOCAL_LLM_MODEL_REVISION="1111111111111111111111111111111111111111"
export LOCAL_LLM_MODEL_FILENAME="fixture.gguf"
export LOCAL_LLM_MODEL_SHA256="$sha256"
export LOCAL_LLM_MODEL_SIZE="$size"
export LOCAL_LLM_MODEL_URL="file://$source_model"
export LOCAL_LLM_MODEL_OWNER="$owner"
export LOCAL_LLM_MODEL_GROUP="$group"

bash "$manager" prepare
model="$LOCAL_LLM_MODEL_DIRECTORY/$sha256-$LOCAL_LLM_MODEL_FILENAME"
receipt="$model.verified.json"
test -f "$model"
test -f "$receipt"
test "$(stat -c %s "$model")" = "$size"
grep -F '"schemaVersion":1' "$receipt" >/dev/null
grep -F "\"sha256\":\"$sha256\"" "$receipt" >/dev/null

rm "$receipt"
LOCAL_LLM_MODEL_URL="file://$temporary/does-not-exist" bash "$manager" prepare
test -f "$receipt"
cmp "$source_model" "$model"

cat >"$temporary/forbid-hash" <<'EOF'
#!/usr/bin/env bash
echo 'unexpected full hash' >&2
exit 99
EOF
chmod +x "$temporary/forbid-hash"
LOCAL_LLM_SHA256SUM="$temporary/forbid-hash" bash "$manager" prepare
if LOCAL_LLM_SHA256SUM="$temporary/forbid-hash" bash "$manager" verify; then
	echo "manual verification did not invoke the full hash" >&2
	exit 1
fi
bash "$manager" verify

chmod 0640 "$model"
printf X | dd of="$model" bs=1 seek=0 conv=notrunc status=none
chmod 0440 "$model"
if bash "$manager" verify; then
	echo "manual verification accepted same-size corruption" >&2
	exit 1
fi
test ! -e "$receipt"
bash "$manager" prepare
cmp "$source_model" "$model"

echo "local model manager tests passed"
