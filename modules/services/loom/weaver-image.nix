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
  neovim,
  starship,
  tmux,
}:
let
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
      sandbox_mode="''${LOOM_CODEX_SANDBOX_MODE:-workspace-write}"
      approval_policy="''${LOOM_CODEX_APPROVAL_POLICY:-never}"
      model="''${LOOM_CODEX_MODEL:-}"

      codex_args=(
        exec
        --sandbox "$sandbox_mode"
        --ask-for-approval "$approval_policy"
      )

      if [ -n "$model" ]; then
        codex_args+=(--model "$model")
      fi

      ${codex}/bin/codex "''${codex_args[@]}" "$prompt"
      exec ${bashInteractive}/bin/bash -i
    fi

    exec ${loom-cli}/bin/loom
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

    if [ -n "''${LOOM_REPO:-}" ]; then
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

    exec ${tmux}/bin/tmux new-session -A -s loom "${sessionLauncher}/bin/weaver-session"
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
      cacert
      etcFiles
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
    mkdir -p /workspace
    mkdir -p /tmp

    chmod 1777 /tmp
    chown -R 1000:1000 /home/loom
    chmod 755 /home/loom
    chown -R 1000:1000 /workspace
    chmod 755 /workspace
  '';

  config = {
    User = "1000:1000";
    Entrypoint = [ "${entrypoint}/bin/entrypoint" ];
    ExposedPorts = { };
    Env = [
      "CODEX_HOME=/home/loom/.codex"
      "HOME=/home/loom"
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
