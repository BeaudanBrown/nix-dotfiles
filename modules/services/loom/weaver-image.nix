{
  buildEnv,
  dockerTools,
  writeShellScriptBin,
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
  gh,
  git,
  jq,
  loom-cli,
  nix,
  neovim,
  starship,
  tmux,
}:
let
  nixConf = writeTextDir "etc/nix/nix.conf" ''
    accept-flake-config = true
    builders-use-substitutes = true
    connect-timeout = 10
    experimental-features = nix-command flakes
    fallback = true
    require-sigs = true
    sandbox = false
    substituters = https://cache.bepis.lol https://cache.nixos.org
    trusted-public-keys = cache.bepis.lol-1:RICGW/iQ761PR6QiMUwbOLcvKird8EHoDd/ylnDOGJY= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  '';

  sessionLauncher = writeShellScriptBin "weaver-session" ''
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
      sandbox_mode="''${LOOM_CODEX_SANDBOX_MODE:-danger-full-access}"
      approval_policy="''${LOOM_CODEX_APPROVAL_POLICY:-never}"
      model="''${LOOM_CODEX_MODEL:-}"

      codex_args=(
        --ask-for-approval "$approval_policy"
        exec
        --sandbox "$sandbox_mode"
      )

      if [ -n "$model" ]; then
        codex_args+=(--model "$model")
      fi

      codex_status=0
      ${codex}/bin/codex "''${codex_args[@]}" "$prompt" || codex_status=$?
      echo "Codex exited with status $codex_status."
      echo "Keeping weaver alive with an interactive shell."

      while true; do
        ${bashInteractive}/bin/bash -i || true
        echo "Shell exited; restarting in 1s."
        sleep 1
      done
    fi

    exec ${loom-cli}/bin/loom
  '';

  tmuxLauncher = writeShellScriptBin "tmux-session-launcher" ''
    #!/bin/bash
    set -uo pipefail

    ${sessionLauncher}/bin/weaver-session
    session_status=$?

    echo "weaver-session exited with status $session_status." >&2
    echo "Keeping tmux session alive for inspection." >&2

    while true; do
      ${bashInteractive}/bin/bash -i || true
      echo "Inspection shell exited; restarting in 1s." >&2
      sleep 1
    done
  '';

  githubForkSetup = writeShellScriptBin "weaver-github-fork-setup" ''
    #!/bin/bash
    set -euo pipefail

    workspace="''${1:-/workspace}"
    upstream_repo="''${LOOM_UPSTREAM_REPO:-}"
    base_branch="''${LOOM_BASE_BRANCH:-main}"
    work_branch="''${LOOM_WORK_BRANCH:-$base_branch}"

    if [ -z "$upstream_repo" ]; then
      echo "LOOM_UPSTREAM_REPO is required for GitHub fork setup." >&2
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

    upstream_slug="$(normalize_github_slug "$upstream_repo")"
    upstream_owner="''${upstream_slug%%/*}"
    repo_name="''${upstream_slug#*/}"

    if [ -z "$upstream_owner" ] || [ -z "$repo_name" ] || [ "$repo_name" = "$upstream_slug" ]; then
      echo "Could not determine owner/repo from $upstream_repo" >&2
      exit 1
    fi

    bot_login="$(${gh}/bin/gh api user --jq .login)"
    fork_slug="$bot_login/$repo_name"
    fork_url="https://github.com/$fork_slug.git"
    upstream_url="https://github.com/$upstream_slug.git"

    if ${gh}/bin/gh repo view "$fork_slug" >/dev/null 2>&1; then
      echo "Using existing fork $fork_slug."
    else
      echo "Creating fork $fork_slug from $upstream_slug..."
      ${gh}/bin/gh repo fork "$upstream_slug" --remote=false --clone=false >/dev/null
    fi

    rm -rf "$workspace"
    echo "Cloning fork $fork_slug into $workspace..."
    ${git}/bin/git clone "$fork_url" "$workspace"

    cd "$workspace"
    ${git}/bin/git remote set-url origin "$fork_url"

    if ${git}/bin/git remote get-url upstream >/dev/null 2>&1; then
      ${git}/bin/git remote set-url upstream "$upstream_url"
    else
      ${git}/bin/git remote add upstream "$upstream_url"
    fi

    ${git}/bin/git fetch origin --prune
    ${git}/bin/git fetch upstream --prune

    if ${git}/bin/git show-ref --verify --quiet "refs/remotes/origin/$work_branch"; then
      echo "Checking out existing fork branch $work_branch."
      ${git}/bin/git checkout -B "$work_branch" "origin/$work_branch"
    elif ${git}/bin/git show-ref --verify --quiet "refs/remotes/upstream/$base_branch"; then
      echo "Creating $work_branch from upstream/$base_branch."
      ${git}/bin/git checkout -B "$work_branch" "upstream/$base_branch"
      ${git}/bin/git push -u origin "$work_branch"
    elif ${git}/bin/git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
      echo "Creating $work_branch from origin/$base_branch."
      ${git}/bin/git checkout -B "$work_branch" "origin/$base_branch"
      ${git}/bin/git push -u origin "$work_branch"
    else
      echo "Base branch '$base_branch' was not found on upstream or origin." >&2
      exit 1
    fi

    echo "GitHub fork workspace ready."
    echo "  upstream: $upstream_url"
    echo "  origin:   $fork_url"
    echo "  branch:   $work_branch"
  '';

  entrypoint = writeShellScriptBin "entrypoint" ''
        #!/bin/bash
        set -euo pipefail

        workspace="/workspace"

        resolve_workspace_path() {
          local input_path="$1"

          if [[ "$input_path" = /* ]]; then
            printf '%s\n' "$input_path"
          else
            printf '%s/%s\n' "$workspace" "$input_path"
          fi
        }

        mkdir -p "$HOME/.codex"

        if [ -n "''${LOOM_CODEX_AUTH_JSON_B64:-}" ]; then
          printf '%s' "$LOOM_CODEX_AUTH_JSON_B64" \
            | ${coreutils}/bin/base64 --decode \
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
          github_bot_pat="$(printf '%s' "$LOOM_GITHUB_BOT_PAT_B64" | ${coreutils}/bin/base64 --decode)"
          export GH_TOKEN="$github_bot_pat"
          export GITHUB_TOKEN="$github_bot_pat"

          mkdir -p "$HOME/.config/gh"
          cat > "$HOME/.config/gh/hosts.yml" <<EOF
    github.com:
        oauth_token: $github_bot_pat
        git_protocol: https
    EOF
          chmod 600 "$HOME/.config/gh/hosts.yml"

          ${git}/bin/git config --global credential."https://github.com".helper "!${gh}/bin/gh auth git-credential"
          ${git}/bin/git config --global credential.helper ""
          ${git}/bin/git config --global url."https://github.com/".insteadOf "git@github.com:"
          ${git}/bin/git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
          ${git}/bin/git config --global user.name "BeaudanBrown Bot"
          ${git}/bin/git config --global user.email "theharoldlewis@gmail.com"
          echo "Installed GitHub bot credentials for gh and git HTTPS."
        fi

        if [ -n "''${LOOM_UPSTREAM_REPO:-}" ] && [ -n "''${GH_TOKEN:-}" ]; then
          ${githubForkSetup}/bin/weaver-github-fork-setup "$workspace"
        elif [ -n "''${LOOM_REPO:-}" ]; then
          echo "Cloning $LOOM_REPO..."

          if [ -n "''${LOOM_BRANCH:-}" ]; then
            ${git}/bin/git clone --branch "$LOOM_BRANCH" --single-branch "$LOOM_REPO" "$workspace"
          else
            ${git}/bin/git clone "$LOOM_REPO" "$workspace"
          fi

          cd "$workspace"
          echo "Cloning complete."
          echo ""
        else
          mkdir -p "$workspace"
          cd "$workspace"
        fi

        export LOOM_WORKSPACE="$workspace"

        ${tmux}/bin/tmux new-session -d -s loom "${tmuxLauncher}/bin/tmux-session-launcher"
        ${tmux}/bin/tmux pipe-pane -t loom:0.0 -o 'cat >&2'
        exec ${tmux}/bin/tmux attach-session -t loom
  '';

  passwdFile = writeTextDir "etc/passwd" ''
    root:x:0:0:root:/root:/bin/bash
    nobody:x:65534:65534:Nobody:/:/sbin/nologin
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

  etcFiles = symlinkJoin {
    name = "etc-merged";
    paths = [
      passwdFile
      groupFile
    ];
  };

  homeFiles = symlinkJoin {
    name = "home-files";
    paths = [ bashrcFile ];
  };
in
dockerTools.buildImage {
  name = "loom-weaver";
  tag = "latest";

  copyToRoot = buildEnv {
    name = "weaver-root";
    paths = [
      loom-cli
      codex
      entrypoint
      sessionLauncher
      tmuxLauncher
      githubForkSetup
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
      dive
      devenv
      direnv
      nix
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

  runAsRoot = ''
    #!${bashInteractive}/bin/bash
    mkdir -p /home/loom
    mkdir -p /home/loom/.cache/nix
    mkdir -p /workspace
    mkdir -p /tmp
    mkdir -p /nix/var/nix/db
    mkdir -p /nix/var/nix/profiles/per-user/loom
    mkdir -p /nix/var/nix/gcroots/per-user/loom

    chmod 1777 /tmp
    chown -R 1000:1000 /home/loom
    chmod 755 /home/loom
    chown -R 1000:1000 /workspace
    chmod 755 /workspace
    chown 1000:1000 /nix
    chown 1000:1000 /nix/var
    chown 1000:1000 /nix/var/nix
    chown 1000:1000 /nix/var/nix/db
    chown 1000:1000 /nix/var/nix/profiles
    chown 1000:1000 /nix/var/nix/profiles/per-user
    chown 1000:1000 /nix/var/nix/profiles/per-user/loom
    chown 1000:1000 /nix/var/nix/gcroots
    chown 1000:1000 /nix/var/nix/gcroots/per-user
    chown 1000:1000 /nix/var/nix/gcroots/per-user/loom
    chmod 755 /nix /nix/var /nix/var/nix
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
      "PATH=/bin"
      "RUST_LOG=info"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "TERM=xterm-256color"
      "USER=loom"
    ];
    WorkingDir = "/workspace";
    Labels = {
      "org.opencontainers.image.description" = "Ephemeral environment for Loom and Codex sessions";
      "org.opencontainers.image.source" = "https://github.com/ghuntley/loom";
      "org.opencontainers.image.title" = "Loom Weaver";
    };
  };
}
