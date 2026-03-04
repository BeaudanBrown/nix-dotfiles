{
  buildEnv,
  dockerTools,
  pkgs,
  cacheSubstituter ? "http://loom-cache.loom-weavers.svc.cluster.local:8080",
  writeShellApplication,
  writeTextDir,
  symlinkJoin,
  bashInteractive,
  btop,
  cacert,
  codex,
  coreutils,
  curl,
  devenv,
  direnv,
  dive,
  findutils,
  gh,
  git,
  jq,
  less,
  loom-cli,
  nix,
  neovim,
  openssh,
  starship,
  tmux,
}:
let
  defaultBuilderSupportedFeatures = "benchmark,big-parallel,kvm,nixos-test";

  # Configure Nix for a true single-user install inside the weaver. This keeps
  # the image compatible with Loom's non-root pod model while still letting a
  # runtime-injected machines file opt into a remote builder.
  nixConf = writeTextDir "etc/nix/nix.conf" ''
    accept-flake-config = true
    always-allow-substitutes = true
    auto-optimise-store = false
    builders = @/home/loom/.config/nix/machines
    builders-use-substitutes = true
    connect-timeout = 10
    experimental-features = nix-command flakes
    fallback = true
    max-jobs = auto
    require-sigs = true
    sandbox = false
    substituters = ${cacheSubstituter} https://cache.nixos.org
    trusted-public-keys = cache.bepis.lol-1:RICGW/iQ761PR6QiMUwbOLcvKird8EHoDd/ylnDOGJY= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  '';

  sessionLauncher = writeShellApplication {
    name = "weaver-session";
    runtimeInputs = [
      bashInteractive
      codex
      direnv
      loom-cli
    ];
    text = ''
      #!/bin/bash
      set -euo pipefail

      workspace="''${LOOM_WORKSPACE:-/workspace}"
      tool="''${LOOM_WEAVER_TOOL:-loom}"

      cd "$workspace"

      resolve_workspace_path() {
        local input_path="$1"

        if [[ "$input_path" = /* ]]; then
          printf '%s\n' "$input_path"
        else
          printf '%s/%s\n' "$workspace" "$input_path"
        fi
      }

      if [ "$tool" = "codex" ]; then
        prompt_file="''${LOOM_CODEX_PROMPT_FILE:-.loom/codex-prompt.md}"
        prompt_path="$(resolve_workspace_path "$prompt_file")"

        if [ ! -f "$prompt_path" ]; then
          echo "Codex prompt file not found: $prompt_path" >&2
          exit 1
        fi

        prompt="$(cat "$prompt_path")"
        mode="''${LOOM_CODEX_MODE:-interactive}"
        sandbox_mode="''${LOOM_CODEX_SANDBOX_MODE:-danger-full-access}"
        approval_policy="''${LOOM_CODEX_APPROVAL_POLICY:-never}"
        model="''${LOOM_CODEX_MODEL:-gpt-5.3-codex}"

        codex_args=(
          --ask-for-approval "$approval_policy"
          --sandbox "$sandbox_mode"
        )

        if [ -n "$model" ]; then
          codex_args+=(--model "$model")
        fi

        case "$mode" in
          interactive)
            codex_args+=(--no-alt-screen)
            ;;
          exec)
            codex_args+=(exec)
            ;;
          *)
            echo "Unsupported Codex mode: $mode" >&2
            exit 1
            ;;
        esac

        codex_status=0
        if [ -f "$workspace/.envrc" ]; then
          direnv exec "$workspace" codex "''${codex_args[@]}" "$prompt" || codex_status=$?
        else
          codex "''${codex_args[@]}" "$prompt" || codex_status=$?
        fi
        echo "Codex exited with status $codex_status."
        echo "Keeping weaver alive with an interactive shell."

        while true; do
          bash -i || true
          echo "Shell exited; restarting in 1s."
          sleep 1
        done
      fi

      exec loom
    '';
  };

  tmuxLauncher = writeShellApplication {
    name = "tmux-session-launcher";
    runtimeInputs = [
      bashInteractive
      sessionLauncher
    ];
    text = ''
      #!/bin/bash
      set -uo pipefail

      weaver-session
      session_status=$?

      echo "weaver-session exited with status $session_status." >&2
      echo "Keeping tmux session alive for inspection." >&2

      while true; do
        bash -i || true
        echo "Inspection shell exited; restarting in 1s." >&2
        sleep 1
      done
    '';
  };

  githubForkSetup = writeShellApplication {
    name = "weaver-github-fork-setup";
    runtimeInputs = [
      findutils
      gh
      git
    ];
    text = ''
      #!/bin/bash
      set -euo pipefail

      workspace="''${1:-/workspace}"
      upstream_repo="''${LOOM_UPSTREAM_REPO:-}"
      fork_owner="''${LOOM_GITHUB_FORK_OWNER:-}"
      base_branch="''${LOOM_BASE_BRANCH:-main}"
      work_branch="''${LOOM_WORK_BRANCH:-$base_branch}"
      branch_policy="''${LOOM_WORK_BRANCH_POLICY:-rebase}"
      prompt_file="''${LOOM_CODEX_PROMPT_FILE:-.loom/codex-prompt.md}"

      if [ -z "$upstream_repo" ]; then
        echo "LOOM_UPSTREAM_REPO is required for GitHub fork setup." >&2
        exit 1
      fi

      if [ -z "$fork_owner" ]; then
        echo "LOOM_GITHUB_FORK_OWNER is required for GitHub fork setup." >&2
        exit 1
      fi

      normalize_github_slug() {
        local raw="$1"
        local path

        case "$raw" in
          https://github.com/*)
            path="''${raw#https://github.com/}"
            ;;
          http://github.com/*)
            path="''${raw#http://github.com/}"
            ;;
          git@github.com:*)
            path="''${raw#git@github.com:}"
            ;;
          ssh://git@github.com/*)
            path="''${raw#ssh://git@github.com/}"
            ;;
          *)
            echo "Unsupported GitHub repository URL: $raw" >&2
            exit 1
            ;;
        esac

        path="''${path%.git}"
        printf '%s\n' "$path"
      }

      resolve_workspace_path() {
        local input_path="$1"

        if [[ "$input_path" = /* ]]; then
          printf '%s\n' "$input_path"
        else
          printf '%s/%s\n' "$workspace" "$input_path"
        fi
      }

      refresh_submodules() {
        if [ ! -f .gitmodules ]; then
          return 0
        fi

        echo "Syncing git submodules..."
        git submodule sync --recursive
        git submodule update --init --recursive
      }

      upstream_slug="$(normalize_github_slug "$upstream_repo")"
      upstream_owner="''${upstream_slug%%/*}"
      repo_name="''${upstream_slug#*/}"

      if [ -z "$upstream_owner" ] || [ -z "$repo_name" ] || [ "$repo_name" = "$upstream_slug" ]; then
        echo "Could not determine owner/repo from $upstream_repo" >&2
        exit 1
      fi

      fork_slug="$fork_owner/$repo_name"
      fork_url="https://github.com/$fork_slug.git"
      upstream_url="https://github.com/$upstream_slug.git"

      if gh repo view "$fork_slug" >/dev/null 2>&1; then
        echo "Using existing fork $fork_slug."
      else
        echo "Creating fork $fork_slug from $upstream_slug..."
        gh repo fork "$upstream_slug" --org "$fork_owner" --remote=false --clone=false >/dev/null
      fi

      if [ -e "$workspace" ] && [ ! -d "$workspace" ]; then
        echo "Workspace path exists but is not a directory: $workspace" >&2
        exit 1
      fi

      mkdir -p "$workspace"
      if [ ! -w "$workspace" ]; then
        echo "Workspace directory is not writable: $workspace" >&2
        exit 1
      fi

      find "$workspace" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      echo "Cloning fork $fork_slug into $workspace..."
      git clone --recurse-submodules "$fork_url" "$workspace"

      cd "$workspace"
      git remote set-url origin "$fork_url"

      if git remote get-url upstream >/dev/null 2>&1; then
        git remote set-url upstream "$upstream_url"
      else
        git remote add upstream "$upstream_url"
      fi

      git fetch origin --prune
      git fetch upstream --prune

      if git show-ref --verify --quiet "refs/remotes/origin/$work_branch"; then
        echo "Checking out existing fork branch $work_branch."
        git checkout -B "$work_branch" "origin/$work_branch"

        case "$branch_policy" in
          reset)
            echo "Resetting $work_branch to upstream/$base_branch."
            git reset --hard "upstream/$base_branch"
            git push --force-with-lease -u origin "$work_branch"
            ;;
          rebase)
            echo "Rebasing $work_branch onto upstream/$base_branch."
            git rebase "upstream/$base_branch"
            git push --force-with-lease -u origin "$work_branch"
            ;;
          reuse-as-is)
            echo "Reusing existing fork branch $work_branch without upstream refresh."
            ;;
          *)
            echo "Unsupported LOOM_WORK_BRANCH_POLICY: $branch_policy" >&2
            exit 1
            ;;
        esac
      elif git show-ref --verify --quiet "refs/remotes/upstream/$base_branch"; then
        echo "Creating $work_branch from upstream/$base_branch."
        git checkout -B "$work_branch" "upstream/$base_branch"
        git push -u origin "$work_branch"
      elif git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
        echo "Creating $work_branch from origin/$base_branch."
        git checkout -B "$work_branch" "origin/$base_branch"
        git push -u origin "$work_branch"
      else
        echo "Base branch '$base_branch' was not found on upstream or origin." >&2
        exit 1
      fi

      refresh_submodules

      prompt_path="$(resolve_workspace_path "$prompt_file")"
      if [ ! -f "$prompt_path" ]; then
        echo "Bootstrap failed: prompt file not found after branch setup." >&2
        echo "  prompt: $prompt_path" >&2
        echo "  branch: $work_branch" >&2
        echo "  base:   $base_branch" >&2
        echo "  policy: $branch_policy" >&2
        exit 1
      fi

      echo "GitHub fork workspace ready."
      echo "  upstream: $upstream_url"
      echo "  origin:   $fork_url"
      echo "  owner:    $fork_owner"
      echo "  branch:   $work_branch"
    '';
  };

  gitAskpass = writeShellApplication {
    name = "weaver-git-askpass";
    text = ''
      #!/bin/bash
      set -euo pipefail

      prompt="''${1:-}"

      case "$prompt" in
        *Username*github.com*)
          printf '%s\n' "x-access-token"
          ;;
        *Password*github.com*)
          if [ -z "''${GH_TOKEN:-}" ]; then
            echo "GH_TOKEN is required for GitHub HTTPS auth." >&2
            exit 1
          fi

          printf '%s\n' "$GH_TOKEN"
          ;;
        *)
          echo "Unsupported Git prompt: $prompt" >&2
          exit 1
          ;;
      esac
    '';
  };

  userEntrypoint = writeShellApplication {
    name = "weaver-user-entrypoint";
    runtimeInputs = [
      coreutils
      direnv
      git
      gh
      githubForkSetup
      gitAskpass
      tmux
      tmuxLauncher
    ];
    text = ''
      #!/bin/bash
      set -euo pipefail

      workspace="/workspace"
      export HOME="/home/loom"
      export USER="loom"
      export LOGNAME="loom"
      export CODEX_HOME="''${CODEX_HOME:-$HOME/.codex}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
      mkdir -p "$XDG_CACHE_HOME"
      mkdir -p "$HOME/.config/nix"
      mkdir -p "$HOME/.local/share/nix"
      mkdir -p "$HOME/.local/state/nix"
      export NIX_USER_CONF_FILES="''${NIX_USER_CONF_FILES:-/etc/nix/nix.conf}"
      export NIX_CONFIG="''${NIX_CONFIG:-accept-flake-config = true}"

      resolve_workspace_path() {
        local input_path="$1"

        if [[ "$input_path" = /* ]]; then
          printf '%s\n' "$input_path"
        else
          printf '%s/%s\n' "$workspace" "$input_path"
        fi
      }

      approve_direnv_workspace() {
        if [ ! -f "$workspace/.envrc" ]; then
          return 0
        fi

        echo "Approving direnv for $workspace..."
        direnv allow "$workspace"
      }

      configure_nix_builder() {
        local builder_host="''${LOOM_NIX_BUILDER_HOST:-}"
        local builder_user="''${LOOM_NIX_BUILDER_USER:-}"
        local builder_port="''${LOOM_NIX_BUILDER_PORT:-22}"
        local builder_systems="''${LOOM_NIX_BUILDER_SYSTEMS:-x86_64-linux}"
        local builder_max_jobs="''${LOOM_NIX_BUILDER_MAX_JOBS:-8}"
        local builder_speed_factor="''${LOOM_NIX_BUILDER_SPEED_FACTOR:-2}"
        local builder_supported_features="''${LOOM_NIX_BUILDER_SUPPORTED_FEATURES:-${defaultBuilderSupportedFeatures}}"
        local builder_required_features="''${LOOM_NIX_BUILDER_REQUIRED_FEATURES:--}"
        local builder_key_b64="''${LOOM_NIX_BUILDER_SSH_KEY_B64:-}"
        local builder_known_hosts_b64="''${LOOM_NIX_BUILDER_KNOWN_HOSTS_B64:-}"
        local builder_alias="loom-builder"
        local machines_file="$HOME/.config/nix/machines"
        local ssh_dir="$HOME/.ssh"
        local ssh_config="$ssh_dir/config"
        local identity_file="$ssh_dir/id_nix_builder"
        local known_hosts_file="$ssh_dir/known_hosts"

        mkdir -p "$(dirname "$machines_file")"
        : > "$machines_file"
        chmod 600 "$machines_file"

        if [ -z "$builder_host" ] || [ -z "$builder_user" ] || [ -z "$builder_key_b64" ]; then
          return 0
        fi

        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        printf '%s' "$builder_key_b64" | base64 --decode > "$identity_file"
        chmod 600 "$identity_file"
        : > "$known_hosts_file"
        chmod 600 "$known_hosts_file"

        if [ -n "$builder_known_hosts_b64" ]; then
          printf '%s' "$builder_known_hosts_b64" | base64 --decode > "$known_hosts_file"
          strict_host_key_checking="yes"
        else
          strict_host_key_checking="accept-new"
        fi

        printf '%s\n' \
          "Host $builder_alias" \
          "  HostName $builder_host" \
          "  User $builder_user" \
          "  Port $builder_port" \
          "  IdentityFile $identity_file" \
          "  IdentitiesOnly yes" \
          "  BatchMode yes" \
          "  ServerAliveInterval 15" \
          "  ServerAliveCountMax 3" \
          "  StrictHostKeyChecking $strict_host_key_checking" \
          "  UserKnownHostsFile $known_hosts_file" \
          > "$ssh_config"
        chmod 600 "$ssh_config"

        if [ -z "$builder_supported_features" ]; then
          builder_supported_features="-"
        fi

        printf 'ssh://%s %s %s %s %s %s %s -\n' \
          "$builder_alias" \
          "$builder_systems" \
          "$identity_file" \
          "$builder_max_jobs" \
          "$builder_speed_factor" \
          "$builder_supported_features" \
          "$builder_required_features" \
          > "$machines_file"
        echo "Configured remote Nix builder via $builder_alias."
      }

      mkdir -p "$HOME/.codex"
      configure_nix_builder

      if [ -n "''${LOOM_CODEX_AUTH_JSON_B64:-}" ]; then
        printf '%s' "$LOOM_CODEX_AUTH_JSON_B64" \
          | base64 --decode \
          > "$HOME/.codex/auth.json"
        chmod 600 "$HOME/.codex/auth.json"
        echo "Installed Codex credentials from LOOM_CODEX_AUTH_JSON_B64."
      elif [ -n "''${LOOM_CODEX_AUTH_FILE:-}" ]; then
        auth_source="$(resolve_workspace_path "$LOOM_CODEX_AUTH_FILE")"

        if [ ! -f "$auth_source" ]; then
          echo "Codex auth file not found: $auth_source" >&2
          exit 1
        fi

        cp "$auth_source" "$HOME/.codex/auth.json"
        chmod 600 "$HOME/.codex/auth.json"
        echo "Installed Codex credentials from $auth_source."
      fi

      if [ -n "''${LOOM_GITHUB_BOT_PAT_B64:-}" ]; then
        github_bot_pat="$(printf '%s' "$LOOM_GITHUB_BOT_PAT_B64" | base64 --decode)"
        export GH_TOKEN="$github_bot_pat"
        export GITHUB_TOKEN="$github_bot_pat"

        mkdir -p "$HOME/.config/gh"
        printf '%s\n' \
          "github.com:" \
          "    oauth_token: $github_bot_pat" \
          "    git_protocol: https" \
          > "$HOME/.config/gh/hosts.yml"
        chmod 600 "$HOME/.config/gh/hosts.yml"

        export GIT_ASKPASS="weaver-git-askpass"
        export GIT_TERMINAL_PROMPT=0

        git config --global core.askPass "$GIT_ASKPASS"
        git config --global credential."https://github.com".username "x-access-token"
        git config --global credential.helper ""
        git config --global url."https://github.com/".insteadOf "git@github.com:"
        git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
        git config --global user.name "BeaudanBrown Bot"
        git config --global user.email "theharoldlewis@gmail.com"
        echo "Installed GitHub bot credentials for gh and git HTTPS."
      fi

      if [ -n "''${LOOM_UPSTREAM_REPO:-}" ] && [ -n "''${GH_TOKEN:-}" ]; then
        weaver-github-fork-setup "$workspace"
      elif [ -n "''${LOOM_REPO:-}" ]; then
        echo "Cloning $LOOM_REPO..."

        if [ -n "''${LOOM_BRANCH:-}" ]; then
          git clone --recurse-submodules --branch "$LOOM_BRANCH" --single-branch "$LOOM_REPO" "$workspace"
        else
          git clone --recurse-submodules "$LOOM_REPO" "$workspace"
        fi

        cd "$workspace"
        if [ -f .gitmodules ]; then
          echo "Syncing git submodules..."
          git submodule sync --recursive
          git submodule update --init --recursive
        fi
        echo "Cloning complete."
        echo ""
      else
        mkdir -p "$workspace"
        cd "$workspace"
      fi

      approve_direnv_workspace

      export LOOM_WORKSPACE="$workspace"

      tmux new-session -d -s loom "tmux-session-launcher"
      exec tmux attach-session -t loom
    '';
  };

  entrypoint = writeShellApplication {
    name = "entrypoint";
    runtimeInputs = [
      userEntrypoint
    ];
    text = ''
      #!/bin/bash
      set -euo pipefail

      exec weaver-user-entrypoint
    '';
  };

  passwdFile = writeTextDir "etc/passwd" ''
    root:x:0:0:root:/root:/bin/bash
    nobody:x:65534:65534:Nobody:/:/bin/false
    loom:x:1000:1000:loom:/home/loom:/bin/bash
  '';

  groupFile = writeTextDir "etc/group" ''
    root:x:0:
    nobody:x:65534:
    loom:x:1000:
  '';

  bashrcFile = writeTextDir "home/loom/.bashrc" ''
    eval "$(${starship}/bin/starship init bash)"
    eval "$(${direnv}/bin/direnv hook bash)"

    export PATH="/bin:$PATH"
    export EDITOR=nvim
    export VISUAL=nvim

    alias vi='nvim'
    alias vim='nvim'

    echo "Welcome to Loom Weaver"
    echo ""
  '';

  direnvrcFile = writeTextDir "home/loom/.config/direnv/direnvrc" ''
    source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
  '';

  etcFiles = symlinkJoin {
    name = "etc-merged";
    paths = [
      passwdFile
      groupFile
    ];
  };

  homeFiles = symlinkJoin {
    name = "home-files";
    paths = [
      bashrcFile
      direnvrcFile
    ];
  };

  weaverRoot = buildEnv {
    name = "weaver-root";
    paths = [
      loom-cli
      codex
      entrypoint
      sessionLauncher
      tmuxLauncher
      githubForkSetup
      gitAskpass
      cacert
      etcFiles
      nixConf
      homeFiles
      git
      curl
      gh
      btop
      tmux
      jq
      less
      dive
      devenv
      direnv
      pkgs.nix-direnv
      nix
      openssh
      starship
      neovim
      coreutils
      bashInteractive
    ];
    pathsToLink = [
      "/bin"
      "/etc"
      "/share"
    ];
  };
in
dockerTools.buildLayeredImageWithNixDb {
  name = "loom-weaver";
  tag = "latest";

  contents = [ weaverRoot ];

  fakeRootCommands = ''
    mkdir -p ./home/loom
    mkdir -p ./home/loom/.cache/nix
    mkdir -p ./home/loom/.config/direnv
    mkdir -p ./home/loom/.config/nix
    mkdir -p ./home/loom/.local/share/nix
    mkdir -p ./home/loom/.local/state/nix
    mkdir -p ./workspace
    mkdir -p ./tmp
    mkdir -p ./nix/store
    mkdir -p ./nix/var/log/nix
    mkdir -p ./nix/var/nix/db
    mkdir -p ./nix/var/nix/gcroots/per-user/loom
    mkdir -p ./nix/var/nix/profiles/per-user/loom
    mkdir -p ./nix/var/nix/temproots
    mkdir -p ./nix/var/nix/userpool
    : > ./home/loom/.config/nix/machines

    chmod 1777 ./tmp
    chown -R 1000:1000 ./home/loom
    chmod 755 ./home/loom
    chown -R 1000:1000 ./workspace
    chmod 755 ./workspace
    chown 1000:1000 ./nix
    chown 1000:1000 ./nix/store
    chown 1000:1000 ./nix/var
    chown 1000:1000 ./nix/var/log
    chown 1000:1000 ./nix/var/log/nix
    chown 1000:1000 ./nix/var/nix
    chown 1000:1000 ./nix/var/nix/db
    chown 1000:1000 ./nix/var/nix/gcroots
    chown 1000:1000 ./nix/var/nix/gcroots/per-user
    chown 1000:1000 ./nix/var/nix/gcroots/per-user/loom
    chown 1000:1000 ./nix/var/nix/profiles
    chown 1000:1000 ./nix/var/nix/profiles/per-user
    chown 1000:1000 ./nix/var/nix/profiles/per-user/loom
    chown 1000:1000 ./nix/var/nix/temproots
    chown 1000:1000 ./nix/var/nix/userpool
    chown -R 1000:1000 ./nix/var/nix/db ./nix/var/nix/gcroots/per-user/loom ./nix/var/nix/profiles/per-user/loom ./nix/var/nix/temproots ./nix/var/nix/userpool
    chmod 1777 ./nix/store
    chmod 755 ./nix ./nix/var ./nix/var/nix
  '';

  config = {
    User = "1000:1000";
    Entrypoint = [ "${entrypoint}/bin/entrypoint" ];
    ExposedPorts = { };
    Env = [
      "CODEX_HOME=/home/loom/.codex"
      "HOME=/home/loom"
      "NIX_CONFIG=accept-flake-config = true"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_USER_CONF_FILES=/etc/nix/nix.conf"
      "PATH=/bin"
      "RUST_LOG=info"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "TERM=xterm-256color"
      "USER=loom"
      "LOGNAME=loom"
      "XDG_CACHE_HOME=/home/loom/.cache"
    ];
    WorkingDir = "/workspace";
    Labels = {
      "org.opencontainers.image.description" = "Ephemeral environment for Loom and Codex sessions";
      "org.opencontainers.image.source" = "https://github.com/ghuntley/loom";
      "org.opencontainers.image.title" = "Loom Weaver";
    };
  };
}
