{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.loom-k3s;
in
{
  options.services.loom-k3s.privateRegistry = {
    enable = mkEnableOption "Enable self-hosted registry secret";

    server = mkOption {
      type = types.str;
      default = "registry.example.com";
      description = "Your registry URL";
    };

    username = mkOption {
      type = types.str;
      default = "admin";
      description = "Registry username";
    };

    passwordFile = mkOption {
      type = types.path;
      description = "Path to file containing the registry password";
    };
  };

  config = mkIf (cfg.privateRegistry.enable && config.services.loom-k3s.enable) {
    # We define a new service that runs alongside the upstream ones
    systemd.services.k3s-custom-registry-secret = {
      description = "Create custom registry secret in loom-weavers namespace";

      # We hook into the upstream services by name
      after = [
        "k3s.service"
        "k3s-loom-namespace.service"
      ];
      requires = [
        "k3s.service"
        "k3s-loom-namespace.service"
      ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.kubectl ];

      script = ''
        until kubectl --kubeconfig=${cfg.kubeconfigPath} get namespace loom-weavers &>/dev/null; do
          sleep 2
        done

        # Clean up old secret
        kubectl --kubeconfig=${cfg.kubeconfigPath} delete secret custom-registry-secret \
          -n loom-weavers --ignore-not-found=true

        # Create new secret
        PASS=$(cat ${cfg.privateRegistry.passwordFile})

        kubectl --kubeconfig=${cfg.kubeconfigPath} create secret docker-registry custom-registry-secret \
          --namespace=loom-weavers \
          --docker-server=${cfg.privateRegistry.server} \
          --docker-username=${cfg.privateRegistry.username} \
          --docker-password="$PASS"
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
