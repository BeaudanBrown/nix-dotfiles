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
  internalCacheServiceName = "loom-cache";
  registryServer = "registry.bepis.lol";
  weaverImage = pkgs.callPackage ./weaver-image.nix {
    cacheSubstituter = "http://${internalCacheServiceName}.loom-weavers.svc.cluster.local:${toString config.custom.ports.assigned.ncps}";
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

  hostedServices = [
    {
      domain = webDomain;
      upstreamPort = toString config.custom.ports.assigned.${webPortKey};
      tailnet = true;
      doNginx = false;
      doACME = false;
    }
  ];

  environment.systemPackages = [
    push-weaver
  ];
  custom.ports.requests = [
    { key = portKey; }
    { key = webPortKey; }
  ];

  networking.firewall.interfaces.cni0.allowedTCPPorts = [ config.hostSpec.sshPort ];

  # Keep ephemeral k3s state on the root NVMe rather than the ZFS /var/lib dataset.
  systemd.tmpfiles.rules = [
    "d /var/k3s-nvme 0755 root root - -"
  ];

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
      "--data-dir=/var/k3s-nvme"
      "--disable=traefik"
      "--disable=metrics-server"
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

  services.nginx.virtualHosts.${webDomain}.listen = lib.mkForce [
    {
      addr = config.hostSpec.tailIP;
      port = 80;
      ssl = false;
    }
    {
      addr = config.hostSpec.tailIP;
      port = 443;
      ssl = true;
    }
  ];

  systemd.services.loom-server = {
    after = [
      "k3s.service"
      "k3s-loom-namespace.service"
      "k3s-kubeconfig-permissions.service"
    ];
    requires = [
      "k3s.service"
      "k3s-loom-namespace.service"
      "k3s-kubeconfig-permissions.service"
    ];
  };
}
