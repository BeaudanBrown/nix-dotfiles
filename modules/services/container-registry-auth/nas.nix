{
  config,
  lib,
  pkgs,
  ...
}:
let
  dockerHubLogin = pkgs.writeShellApplication {
    name = "docker-hub-login";
    runtimeInputs = [
      config.virtualisation.podman.package
      pkgs.coreutils
    ];
    text = ''
      username="$(cat "${config.sops.secrets."docker-hub/username".path}")"
      password_file="${config.sops.secrets."docker-hub/password".path}"

      for attempt in $(seq 1 12); do
        if podman login docker.io --username "$username" --password-stdin < "$password_file"; then
          exit 0
        fi

        if [ "$attempt" -lt 12 ]; then
          echo "docker-hub-login attempt $attempt failed; retrying" >&2
          sleep 30
        fi
      done

      echo "docker-hub-login failed after 12 attempts" >&2
      exit 1
    '';
  };

  ociContainerServices =
    config.virtualisation.oci-containers.containers
    |> lib.mapAttrs' (
      _: container:
      lib.nameValuePair container.serviceName {
        after = [ "docker-hub-login.service" ];
        wants = [ "docker-hub-login.service" ];
      }
    );

  sopsInstallService = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
  networkOnlineService = [ "network-online.target" ];
in
{
  sops.secrets."docker-hub/username" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
  };

  sops.secrets."docker-hub/password" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
  };

  systemd.services = {
    docker-hub-login = {
      description = "Log in to Docker Hub for root Podman pulls";
      wantedBy = [ "multi-user.target" ];
      after = sopsInstallService ++ networkOnlineService;
      requires = sopsInstallService;
      wants = networkOnlineService;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${dockerHubLogin}/bin/docker-hub-login";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  }
  // ociContainerServices;
}
