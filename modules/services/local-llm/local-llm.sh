#!/usr/bin/env bash
set -euo pipefail

service=llama-cpp.service

usage() {
	cat <<'EOF'
Usage: local-llm <command>

Commands:
  up       Start the Grill router and wait for it to become healthy
  warm     Start the router and load the default model with a tiny request
  down     Stop the router and unload the model
  restart  Restart the router and wait for it to become healthy
  status   Show the systemd service state and endpoint health
  health   Query the llama.cpp health endpoint
  logs     Follow the llama.cpp service journal on Grill
EOF
}

run_on_server() {
	if [[ $LOCAL_LLM_IS_SERVER == true ]]; then
		"$@"
	else
		# Arguments are fixed by this script; expansion on the client is intentional.
		# shellcheck disable=SC2029
		ssh "$LOCAL_LLM_SERVER_HOST" "$@"
	fi
}

control_service() {
	local action=$1
	run_on_server sudo -n /run/current-system/sw/bin/systemctl "$action" "$service"
}

authorized_curl() {
	local api_key
	api_key=$(<"$LOCAL_LLM_API_KEY_FILE")
	printf 'header = "Authorization: Bearer %s"\n' "$api_key" | curl --config - "$@"
}

wait_until_healthy() {
	for _ in {1..120}; do
		if authorized_curl --fail --silent --show-error "$LOCAL_LLM_HEALTH_URL" >/dev/null 2>&1; then
			printf 'Local LLM router is ready at %s\n' "$LOCAL_LLM_BASE_URL"
			return 0
		fi
		sleep 1
	done

	echo "Timed out waiting for $LOCAL_LLM_HEALTH_URL" >&2
	return 1
}

command=${1:-}
case "$command" in
up)
	control_service start
	wait_until_healthy
	;;
warm)
	control_service start
	wait_until_healthy
	payload=$(jq -n --arg model "$LOCAL_LLM_DEFAULT_MODEL" '{
      model: $model,
      messages: [{role: "user", content: "Reply with exactly: ready"}],
      temperature: 0,
      max_tokens: 8,
      stream: false,
      chat_template_kwargs: {
        enable_thinking: false,
        preserve_thinking: true
      }
    }')
	authorized_curl \
		--fail \
		--silent \
		--show-error \
		--header 'Content-Type: application/json' \
		--data "$payload" \
		"$LOCAL_LLM_BASE_URL/chat/completions" |
		jq '{model, content: .choices[0].message.content, usage}'
	;;
down)
	control_service stop
	;;
restart)
	control_service restart
	wait_until_healthy
	;;
status)
	run_on_server /run/current-system/sw/bin/systemctl --no-pager status "$service" || true
	if authorized_curl --fail --silent "$LOCAL_LLM_HEALTH_URL" | jq .; then
		printf 'Endpoint: %s\n' "$LOCAL_LLM_BASE_URL"
	else
		echo "Endpoint is unavailable: $LOCAL_LLM_BASE_URL" >&2
		exit 1
	fi
	;;
health)
	authorized_curl --fail --silent --show-error "$LOCAL_LLM_HEALTH_URL" | jq .
	;;
logs)
	if [[ $LOCAL_LLM_IS_SERVER == true ]]; then
		exec journalctl --follow --unit "$service"
	else
		exec ssh "$LOCAL_LLM_SERVER_HOST" journalctl --follow --unit "$service"
	fi
	;;
*)
	usage >&2
	exit 2
	;;
esac
