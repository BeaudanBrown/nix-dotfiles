{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  webDomain = "loom.bepis.lol";
  registryServer = "registry.bepis.lol";

  pkgsLoom = pkgs.unstable.extend (
    lib.composeManyExtensions [
      (import "${inputs.loom}/infra/pkgs" { })
    ]
  );

  codexWeaverEnv = pkgs.writeShellApplication {
    name = "loom-codex-weaver-env";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      set -euo pipefail

      prompt_file=".loom/codex-prompt.md"
      sandbox_mode="danger-full-access"
      approval_policy="never"
      model=""

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --prompt-file)
            prompt_file="$2"
            shift 2
            ;;
          --sandbox)
            sandbox_mode="$2"
            shift 2
            ;;
          --approval)
            approval_policy="$2"
            shift 2
            ;;
          --model)
            model="$2"
            shift 2
            ;;
          *)
            echo "Unknown argument: $1" >&2
            echo "Usage: loom-codex-weaver-env [--prompt-file PATH] [--sandbox MODE] [--approval POLICY] [--model MODEL]" >&2
            exit 1
            ;;
        esac
      done

      auth_b64="$(base64 -w0 < ${config.sops.secrets."loom/codex_auth_json".path})"
      github_bot_pat_b64="$(base64 -w0 < ${config.sops.secrets."loom/github_bot_pat".path})"

      jq -n \
        --arg prompt_file "$prompt_file" \
        --arg sandbox_mode "$sandbox_mode" \
        --arg approval_policy "$approval_policy" \
        --arg auth_b64 "$auth_b64" \
        --arg github_bot_pat_b64 "$github_bot_pat_b64" \
        --arg model "$model" \
        '
          {
            LOOM_WEAVER_TOOL: "codex",
            LOOM_CODEX_PROMPT_FILE: $prompt_file,
            LOOM_CODEX_SANDBOX_MODE: $sandbox_mode,
            LOOM_CODEX_APPROVAL_POLICY: $approval_policy,
            LOOM_CODEX_AUTH_JSON_B64: $auth_b64,
            LOOM_GITHUB_BOT_PAT_B64: $github_bot_pat_b64
          }
          + (if $model == "" then {} else { LOOM_CODEX_MODEL: $model } end)
        '
    '';
  };

  codexWeaver = pkgs.writeShellApplication {
    name = "loom-codex-weaver";
    runtimeInputs = with pkgs; [
      coreutils
      git
      jq
      gnused
    ];
    text = ''
      set -euo pipefail

      server_url="https://${webDomain}"
      image="${registryServer}/loom/weaver:latest"
      prompt_file=".loom/codex-prompt.md"
      sandbox_mode="danger-full-access"
      approval_policy="never"
      model=""
      org=""
      repo_override=""
      feature=""
      base_override=""
      branch_override=""
      ttl=""

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --server-url)
            server_url="$2"
            shift 2
            ;;
          --image)
            image="$2"
            shift 2
            ;;
          --prompt-file)
            prompt_file="$2"
            shift 2
            ;;
          --sandbox)
            sandbox_mode="$2"
            shift 2
            ;;
          --approval)
            approval_policy="$2"
            shift 2
            ;;
          --model)
            model="$2"
            shift 2
            ;;
          --org)
            org="$2"
            shift 2
            ;;
          --repo)
            repo_override="$2"
            shift 2
            ;;
          --feature)
            feature="$2"
            shift 2
            ;;
          --base)
            base_override="$2"
            shift 2
            ;;
          --branch)
            branch_override="$2"
            shift 2
            ;;
          --ttl)
            ttl="$2"
            shift 2
            ;;
          *)
            echo "Unknown argument: $1" >&2
            echo "Usage: loom-codex-weaver [--server-url URL] [--image IMAGE] [--prompt-file PATH] [--sandbox MODE] [--approval POLICY] [--model MODEL] [--org ORG] [--repo URL] [--feature NAME] [--base NAME] [--branch NAME] [--ttl HOURS]" >&2
            exit 1
            ;;
        esac
      done

      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "loom-codex-weaver must be run inside a git repository." >&2
        exit 1
      }

      cd "$repo_root"

      current_branch="$(git branch --show-current)"
      if [ -z "$current_branch" ]; then
        echo "Current checkout is detached; pass --base or --branch explicitly." >&2
        exit 1
      fi

      sanitize_feature() {
        local value
        value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
        value="''${value// /-}"
        value="''${value//\//-}"
        value="$(printf '%s' "$value" | tr -cs '[:alnum:]._-' '-')"
        value="$(printf '%s' "$value" | sed -e 's/^-*//' -e 's/-*$//')"
        if [ -z "$value" ]; then
          echo "Feature name resolves to an empty branch slug." >&2
          exit 1
        fi
        printf '%s\n' "$value"
      }

      if [ -n "$base_override" ]; then
        base_branch="$base_override"
      else
        base_branch="$current_branch"
      fi

      if [ -n "$branch_override" ]; then
        work_branch="$branch_override"
      elif [ -n "$feature" ]; then
        work_branch="weaver/$(sanitize_feature "$feature")"
      else
        work_branch="weaver/$current_branch"
      fi

      normalize_repo_url() {
        local raw="$1"
        case "$raw" in
          https://*|http://*)
            printf '%s\n' "$raw"
            ;;
          git@*:* )
            local host path
            host="$(printf '%s' "$raw" | cut -d'@' -f2 | cut -d: -f1)"
            path="$(printf '%s' "$raw" | cut -d: -f2-)"
            printf 'https://%s/%s\n' "$host" "$path"
            ;;
          ssh://git@* )
            local rest host path
            rest="''${raw#ssh://git@}"
            host="''${rest%%/*}"
            path="''${rest#*/}"
            printf 'https://%s/%s\n' "$host" "$path"
            ;;
          *)
            echo "Unsupported git remote URL: $raw" >&2
            echo "Pass --repo with an https clone URL." >&2
            exit 1
            ;;
        esac
      }

      if [ -n "$repo_override" ]; then
        repo_url="$repo_override"
      else
        repo_url="$(git remote get-url origin 2>/dev/null)" || {
          echo "Could not determine git remote 'origin'; pass --repo explicitly." >&2
          exit 1
        }
        repo_url="$(normalize_repo_url "$repo_url")"
      fi

      if [[ "$prompt_file" = /* ]]; then
        prompt_path="$prompt_file"
      else
        prompt_path="$repo_root/$prompt_file"
      fi

      if [ ! -f "$prompt_path" ]; then
        echo "Prompt file not found: $prompt_path" >&2
        exit 1
      fi

      env_cmd=(
        ${codexWeaverEnv}/bin/loom-codex-weaver-env
        --prompt-file "$prompt_file"
        --sandbox "$sandbox_mode"
        --approval "$approval_policy"
      )

      if [ -n "$model" ]; then
        env_cmd+=(--model "$model")
      fi

      cmd=(
        ${pkgsLoom.loom-cli}/bin/loom
        --server-url "$server_url"
        weaver
        new
        --image "$image"
        -e "LOOM_UPSTREAM_REPO=$repo_url"
        -e "LOOM_BASE_BRANCH=$base_branch"
        -e "LOOM_WORK_BRANCH=$work_branch"
      )

      if [ -n "$org" ]; then
        cmd+=(--org "$org")
      fi

      if [ -n "$ttl" ]; then
        cmd+=(--ttl "$ttl")
      fi

      while IFS=$'\t' read -r key value; do
        cmd+=(-e "$key=$value")
      done < <("''${env_cmd[@]}" | jq -r 'to_entries[] | [.key, .value] | @tsv')

      exec "''${cmd[@]}"
    '';
  };
in
{
  sops.secrets =
    lib.mapAttrs (_: secret: secret // { sopsFile = lib.custom.sopsFileForModule __curPos.file; })
      {
        "loom/codex_auth_json" = {
          owner = config.hostSpec.username;
          inherit (config.users.users.${config.hostSpec.username}) group;
        };

        "loom/github_bot_pat" = {
          owner = config.hostSpec.username;
          inherit (config.users.users.${config.hostSpec.username}) group;
        };
      };

  environment.systemPackages = [
    pkgsLoom.loom-cli
    codexWeaver
    codexWeaverEnv
  ];
}
