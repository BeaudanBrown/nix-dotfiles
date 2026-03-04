{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.loom-k3s;
  internalBuilderServiceName = "loom-builder";
  internalBuilderPort = config.hostSpec.sshPort;
  internalCacheServiceName = "loom-cache";
  internalCachePort = config.custom.ports.assigned.ncps;
in
{
  options.services.loom-k3s.privateRegistry = {
    enable = mkEnableOption "Enable self-hosted registry secret";

    secretName = mkOption {
      type = types.str;
      default = "custom-registry-secret";
      description = "Name of the Kubernetes docker-registry secret to create.";
    };

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

  config = mkIf config.services.loom-k3s.enable {
    # We define a new service that runs alongside the upstream ones
    systemd.services.k3s-custom-registry-secret = mkIf cfg.privateRegistry.enable {
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
        kubectl --kubeconfig=${cfg.kubeconfigPath} delete secret ${cfg.privateRegistry.secretName} \
          -n loom-weavers --ignore-not-found=true

        # Create new secret
        PASS=$(cat ${cfg.privateRegistry.passwordFile})

        kubectl --kubeconfig=${cfg.kubeconfigPath} create secret docker-registry ${cfg.privateRegistry.secretName} \
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

    systemd.services.k3s-loom-cache-service = mkIf config.services.ncps.enable {
      description = "Create internal loom cache service in loom-weavers namespace";
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

        cat <<EOF | kubectl --kubeconfig=${cfg.kubeconfigPath} apply -f -
        apiVersion: v1
        kind: Service
        metadata:
          name: ${internalCacheServiceName}
          namespace: loom-weavers
        spec:
          ports:
            - name: http
              port: ${toString internalCachePort}
              protocol: TCP
        ---
        apiVersion: v1
        kind: Endpoints
        metadata:
          name: ${internalCacheServiceName}
          namespace: loom-weavers
        subsets:
          - addresses:
              - ip: ${config.hostSpec.tailIP}
            ports:
              - name: http
                port: ${toString internalCachePort}
                protocol: TCP
        EOF
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.k3s-loom-builder-service = mkIf config.services.openssh.enable {
      description = "Create internal loom builder service in loom-weavers namespace";
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

        cat <<EOF | kubectl --kubeconfig=${cfg.kubeconfigPath} apply -f -
        apiVersion: v1
        kind: Service
        metadata:
          name: ${internalBuilderServiceName}
          namespace: loom-weavers
        spec:
          ports:
            - name: ssh
              port: ${toString internalBuilderPort}
              protocol: TCP
        ---
        apiVersion: v1
        kind: Endpoints
        metadata:
          name: ${internalBuilderServiceName}
          namespace: loom-weavers
        subsets:
          - addresses:
              - ip: ${config.hostSpec.tailIP}
            ports:
              - name: ssh
                port: ${toString internalBuilderPort}
                protocol: TCP
        EOF
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
