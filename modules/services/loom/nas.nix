{
  config,
  inputs,
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  portKey = "loom";
  webDomain = "loom.bepis.lol";
  webPortKey = "loom-web";
  weaverImage = inputs.loom.packages.${pkgs.system}.weaver-image;
  registryServer = "registry.bepis.lol";
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

in
{
  imports = [
    ./patch.nix
  ];

  environment.systemPackages = [
    push-weaver
  ];
  custom.ports.requests = [
    { key = portKey; }
    { key = webPortKey; }
  ];

  fileSystems."/var/lib/rancher/k3s" = {
    device = "/var/k3s-nvme";
    options = [ "bind" ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      loom-web = prev.callPackage "${inputs.loom}/infra/pkgs/loom-web.nix" {
        fetchPnpmDeps = pkgsUnstable.pnpm_9.fetchDeps;
        pnpmConfigHook = pkgsUnstable.pnpm_9.configHook;
      };
    })
  ];

  sops.secrets = lib.mkIf config.services.loom-server.enable {
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

    "loom/master_key" = {
      owner = "loom-server";
      group = "loom-server";
    };

    "cloudflare/dns_api_token" = { };
  };

  # systemd.services.k3s-kubeconfig-symlink = lib.mkForce {
  #   description = "Create symlink to k3s kubeconfig for loom-server";
  #   after = [ "k3s.service" ];
  #   requires = [ "k3s.service" ];
  #   wantedBy = [ "multi-user.target" ];

  #   script = ''
  #     # Wait for kubeconfig to exist
  #     until [ -f ${config.services.loom-k3s.kubeconfigPath} ]; do
  #       echo "Waiting for kubeconfig..."
  #       sleep 2
  #     done

  #     # Create a directory with loom-server:loom-server permissions
  #     mkdir -p /var/lib/loom-server/kubeconfig
  #     chown loom-server:loom-server /var/lib/loom-server/kubeconfig
  #     chmod 750 /var/lib/loom-server/kubeconfig

  #     # Remove old symlink if it exists
  #     rm -f /var/lib/loom-server/kubeconfig/kubeconfig

  #     # Create symlink
  #     ln -s ${config.services.loom-k3s.kubeconfigPath} /var/lib/loom-server/kubeconfig/kubeconfig
  #   '';

  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };
  # };

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
  #     until kubectl get namespace loom-weavers &>/dev/null; do sleep 2; done

  #     # Create/Update the secret
  #     kubectl create secret docker-registry ${registrySecretName} \
  #       --namespace=loom-weavers \
  #       --docker-server=${registryServer} \
  #       --docker-username=beau \
  #       --docker-password="$(cat ${config.sops.secrets."docker-registry/pass".path})" \
  #       --dry-run=client -o yaml | kubectl apply -f -
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
    package = inputs.loom.packages.${pkgs.system}.loom-server;
    host = "0.0.0.0";
    port = config.custom.ports.assigned.${portKey};
    baseUrl = "https://${webDomain}";
    binDir = inputs.loom.packages.${pkgs.system}.loom-server-binaries;

    weaver = {
      enable = true;
      imagePullSecrets = [ registrySecretName ];
      # kubeconfigPath = "/var/lib/loom-server/kubeconfig/kubeconfig";
    };

    anthropic = {
      enable = true;
      apiKeyFile = config.sops.secrets."loom/anthropic_api_key".path;
      model = "claude-sonnet-4-5";
    };

    openai = {
      enable = true;
      apiKeyFile = config.sops.secrets."loom/openai_api_key".path;
      model = "gpt-5.2";
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
    package = pkgs.loom-web;
    port = config.custom.ports.assigned.${webPortKey};
    domain = webDomain;
    serverUrl = "http://127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
    enableSSL = true;
    acmeEmail = config.hostSpec.email;
    acmeDnsProvider = "cloudflare";
    acmeDnsCredentialsFile = config.sops.secrets."cloudflare/dns_api_token".path;
  };
}
