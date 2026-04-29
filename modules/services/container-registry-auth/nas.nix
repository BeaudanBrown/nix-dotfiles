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

      podman login docker.io --username "$username" --password-stdin < "$password_file"
    '';
  };

  ociContainerServices =
    config.virtualisation.oci-containers.containers
    |> lib.mapAttrs' (
      _: container:
      lib.nameValuePair container.serviceName {
        after = [ "docker-hub-login.service" ];
        requires = [ "docker-hub-login.service" ];
      }
    );
in
{
  sops.secrets."docker-hub/username" = {
    sopsFile = lib.custom.sopsRootFile "server";
    mode = "0400";
  };

  sops.secrets."docker-hub/password" = {
    sopsFile = lib.custom.sopsRootFile "server";
    mode = "0400";
  };

  systemd.services = {
    docker-hub-login = {
      description = "Log in to Docker Hub for root Podman pulls";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];
      requires = [ "sops-nix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${dockerHubLogin}/bin/docker-hub-login";
      };
    };
  }
  // ociContainerServices;
}
