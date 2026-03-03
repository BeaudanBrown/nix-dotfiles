{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  portKey = "loom";
  webDomain = "loom.bepis.lol";
  webPortKey = "loom-web";
  registryServer = "registry.bepis.lol";
  codexWeaverEnv = pkgs.writeShellApplication {
    name = "loom-codex-weaver-env";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      set -euo pipefail

      prompt_file=".loom/codex-prompt.md"
      sandbox_mode="workspace-write"
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

      jq -n \
        --arg prompt_file "$prompt_file" \
        --arg sandbox_mode "$sandbox_mode" \
        --arg approval_policy "$approval_policy" \
        --arg auth_b64 "$auth_b64" \
        --arg model "$model" \
        '
          {
            LOOM_WEAVER_TOOL: "codex",
            LOOM_CODEX_PROMPT_FILE: $prompt_file,
            LOOM_CODEX_SANDBOX_MODE: $sandbox_mode,
            LOOM_CODEX_APPROVAL_POLICY: $approval_policy,
            LOOM_CODEX_AUTH_JSON_B64: $auth_b64
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
    ];
    text = ''
      set -euo pipefail

      server_url="https://${webDomain}"
      image="${registryServer}/loom/weaver:latest"
      prompt_file=".loom/codex-prompt.md"
      sandbox_mode="workspace-write"
      approval_policy="never"
      model=""
      org=""
      repo_override=""
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
            echo "Usage: loom-codex-weaver [--server-url URL] [--image IMAGE] [--prompt-file PATH] [--sandbox MODE] [--approval POLICY] [--model MODEL] [--org ORG] [--repo URL] [--branch NAME] [--ttl HOURS]" >&2
            exit 1
            ;;
        esac
      done

      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "loom-codex-weaver must be run inside a git repository." >&2
        exit 1
      }

      cd "$repo_root"

      if [ -n "$branch_override" ]; then
        branch="$branch_override"
      else
        branch="$(git branch --show-current)"
        if [ -z "$branch" ]; then
          echo "Current checkout is detached; pass --branch explicitly." >&2
          exit 1
        fi
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
        --repo "$repo_url"
        --branch "$branch"
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
  weaverImage = pkgs.callPackage ./weaver-image.nix {
    codex = inputs.nix-ai-tools.packages.${pkgs.system}.codex;
    loom-cli = pkgsLoom.loom-cli;
  };
  push-weaver = pkgs.writeShellScriptBin "push-weaver" ''
    # Configuration placeholders
    REGISTRY=${registryServer}
    REPO="loom/weaver"
    TAG="latest"
    DEST="docker://$REGISTRY/$REPO:$TAG"

    echo "Pushing $weaverImage to $DEST..."

    # Use skopeo to copy the image directly from the Nix store to your registry
    ${pkgs.skopeo}/bin/skopeo copy \
      --insecure-policy \
      docker-archive:${weaverImage} \
      $DEST

    echo "Push complete!"
  '';

  registrySecretName = "tailscale-auth";

  pkgsLoom = pkgs.unstable.extend (
    lib.composeManyExtensions [
      (import "${inputs.loom}/infra/pkgs" { })
    ]
  );
in
{
  imports = [
    ./patch.nix
  ];

  environment.systemPackages = [
    codexWeaver
    codexWeaverEnv
    push-weaver
  ];
  custom.ports.requests = [
    { key = portKey; }
    { key = webPortKey; }
  ];

  # fileSystems."/var/lib/rancher/k3s" = {
  #   device = "/var/k3s-nvme";
  #   options = [ "bind" ];
  # };

  sops.secrets = lib.mkIf config.services.loom-server.enable (
    lib.mapAttrs (_: secret: secret // { sopsFile = lib.custom.sopsFileForModule __curPos.file; }) {
      "loom/headscale_key" = { };

      "docker-registry/pass" = { };

      "loom/google_search_id" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/google_search_api_key" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/github_app_webhook_secret" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/github_app_private_key" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/github_app_id" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/github_oauth_secret" = {
        owner = "loom-server";
        group = "loom-server";
      };
      "loom/github_oauth_id" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/anthropic_api_key" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/openai_api_key" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "loom/codex_auth_json" = {
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
      };

      "loom/master_key" = {
        owner = "loom-server";
        group = "loom-server";
      };

      "cloudflare/dns_api_token" = { };
    }
  );

  # systemd.services.create-registry-secret = {
  #   description = "Create private registry secret for loom weavers";
  #   after = [
  #     "k3s.service"
  #     "k3s-loom-namespace.service"
  #   ];
  #   requires = [
  #     "k3s.service"
  #     "k3s-loom-namespace.service"
  #   ];
  #   wantedBy = [ "multi-user.target" ];
  #   path = [ pkgs.kubectl ];
  #   script = ''
  #     # Wait for namespace
  #     until kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get namespace loom-weavers &>/dev/null; do
  #       echo "Waiting for loom-weavers namespace..."
  #       sleep 2
  #     done

  #     # Create/Update the secret
  #     kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml create secret docker-registry ${registrySecretName} \
  #       --namespace=loom-weavers \
  #       --docker-server=${registryServer} \
  #       --docker-username=beau \
  #       --docker-password="$(cat ${config.sops.secrets."docker-registry/pass".path})"

  #       echo "Created ${registrySecretName} in loom-weavers namespace"
  #   '';
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };
  # };

  services.loom-k3s = {
    enable = true;
    role = "server";
    disableTraefik = true;
    openFirewall = true;
    ghcrSecret.enable = false;
    privateRegistry = {
      enable = true;
      secretName = registrySecretName;
      server = registryServer;
      username = "beau";
      passwordFile = config.sops.secrets."docker-registry/pass".path;
    };
  };

  services.k3s = {
    extraFlags = lib.mkForce (toString [
      "--bind-address=0.0.0.0"
      "--disable=traefik"
      "--tls-san=${config.hostSpec.tailIP}"
      "--tls-san=nas"
    ]);
  };

  services.loom-server = {
    enable = true;
    package = pkgsLoom.loom-server;
    host = "0.0.0.0";
    port = config.custom.ports.assigned.${portKey};
    baseUrl = "https://${webDomain}";
    binDir = pkgsLoom.loom-server-binaries;

    weaver = {
      enable = true;
      imagePullSecrets = [ registrySecretName ];
      audit = {
        enable = false;
      };
    };

    anthropic = {
      enable = true;
      apiKeyFile = config.sops.secrets."loom/anthropic_api_key".path;
    };

    openai = {
      enable = true;
      apiKeyFile = config.sops.secrets."loom/openai_api_key".path;
    };

    secrets = {
      enable = true;
      masterKeyFile = config.sops.secrets."loom/master_key".path;
    };

    githubOAuth = {
      enable = true;
      clientIdFile = config.sops.secrets."loom/github_oauth_id".path;
      clientSecretFile = config.sops.secrets."loom/github_oauth_secret".path;
      redirectUri = "https://${webDomain}/auth/github/callback";
    };

    githubApp = {
      enable = true;
      appIdFile = config.sops.secrets."loom/github_app_id".path;
      privateKeyFile = config.sops.secrets."loom/github_app_private_key".path;
      webhookSecretFile = config.sops.secrets."loom/github_app_webhook_secret".path;
      slug = "loom-bepis";
    };

    googleCse = {
      enable = true;
      apiKeyFile = config.sops.secrets."loom/google_search_api_key".path;
      searchEngineIdFile = config.sops.secrets."loom/google_search_id".path;
    };
  };

  services.loom-web = {
    enable = true;
    package = pkgsLoom.loom-web;
    port = config.custom.ports.assigned.${webPortKey};
    domain = webDomain;
    serverUrl = "http://127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
    enableSSL = true;
    acmeEmail = config.hostSpec.email;
    acmeDnsProvider = "cloudflare";
    acmeDnsCredentialsFile = config.sops.secrets."cloudflare/dns_api_token".path;
  };
}
