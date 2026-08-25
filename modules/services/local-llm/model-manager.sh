#!/usr/bin/env bash
set -euo pipefail

: "${LOCAL_LLM_MODEL_DIRECTORY:?required}"
: "${LOCAL_LLM_MODEL_REPOSITORY:?required}"
: "${LOCAL_LLM_MODEL_REVISION:?required}"
: "${LOCAL_LLM_MODEL_FILENAME:?required}"
: "${LOCAL_LLM_MODEL_SHA256:?required}"
: "${LOCAL_LLM_MODEL_SIZE:?required}"
: "${LOCAL_LLM_MODEL_URL:?required}"
: "${LOCAL_LLM_MODEL_OWNER:?required}"
: "${LOCAL_LLM_MODEL_GROUP:?required}"

sha256sum_command=${LOCAL_LLM_SHA256SUM:-sha256sum}
model="$LOCAL_LLM_MODEL_DIRECTORY/$LOCAL_LLM_MODEL_SHA256-$LOCAL_LLM_MODEL_FILENAME"
receipt="$model.verified.json"
partial="$model.part"

expected_receipt=$(
	cat <<EOF
{"schemaVersion":1,"repository":"$LOCAL_LLM_MODEL_REPOSITORY","revision":"$LOCAL_LLM_MODEL_REVISION","filename":"$LOCAL_LLM_MODEL_FILENAME","sha256":"$LOCAL_LLM_MODEL_SHA256","size":$LOCAL_LLM_MODEL_SIZE}
EOF
)

is_regular_file() {
	[[ -f $1 && ! -L $1 ]]
}

model_metadata_matches() {
	is_regular_file "$model" &&
		[[ $(stat -c %s "$model") == "$LOCAL_LLM_MODEL_SIZE" ]] &&
		[[ $(stat -c %U "$model") == "$LOCAL_LLM_MODEL_OWNER" ]] &&
		[[ $(stat -c %G "$model") == "$LOCAL_LLM_MODEL_GROUP" ]] &&
		[[ $(stat -c %a "$model") == 440 ]]
}

receipt_matches() {
	is_regular_file "$receipt" &&
		[[ $(stat -c %U "$receipt") == "$LOCAL_LLM_MODEL_OWNER" ]] &&
		[[ $(stat -c %G "$receipt") == "$LOCAL_LLM_MODEL_GROUP" ]] &&
		[[ $(stat -c %a "$receipt") == 440 ]] &&
		[[ $(cat "$receipt") == "$expected_receipt" ]]
}

full_hash_matches() {
	local actual
	actual=$($sha256sum_command "$model" | cut -d' ' -f1)
	[[ $actual == "$LOCAL_LLM_MODEL_SHA256" ]]
}

publish_receipt() {
	local temporary="$receipt.tmp"
	printf '%s\n' "$expected_receipt" >"$temporary"
	chmod 0440 "$temporary"
	mv -f "$temporary" "$receipt"
}

verify_existing() {
	if ! model_metadata_matches; then
		rm -f "$receipt"
		return 1
	fi
	if ! full_hash_matches; then
		rm -f "$receipt"
		return 1
	fi
	publish_receipt
	return 0
}

download_and_verify() {
	rm -f "$model" "$receipt"
	curl \
		--continue-at - \
		--fail \
		--location \
		--output "$partial" \
		--retry 3 \
		--retry-all-errors \
		"$LOCAL_LLM_MODEL_URL"
	if [[ $(stat -c %s "$partial") != "$LOCAL_LLM_MODEL_SIZE" ]]; then
		rm -f "$partial"
		echo "Pinned local model has an unexpected byte size" >&2
		return 1
	fi
	chmod 0440 "$partial"
	mv -f "$partial" "$model"
	if ! verify_existing; then
		rm -f "$model"
		echo "Pinned local model failed SHA-256 verification" >&2
		return 1
	fi
}

mkdir -p "$LOCAL_LLM_MODEL_DIRECTORY"
chmod 0750 "$LOCAL_LLM_MODEL_DIRECTORY"

case ${1:-} in
prepare)
	if model_metadata_matches && receipt_matches; then
		printf 'Pinned local model receipt accepted: %s\n' "$model"
	elif verify_existing; then
		printf 'Pinned local model verified and receipt refreshed: %s\n' "$model"
	else
		download_and_verify
		printf 'Pinned local model downloaded and verified: %s\n' "$model"
	fi
	;;
verify)
	if verify_existing; then
		printf 'Pinned local model full verification passed: %s\n' "$model"
	else
		echo "Pinned local model full verification failed" >&2
		exit 1
	fi
	;;
*)
	echo "Usage: $0 {prepare|verify}" >&2
	exit 2
	;;
esac
