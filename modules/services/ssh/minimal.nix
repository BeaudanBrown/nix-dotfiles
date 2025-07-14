{ config, ... }:
{
  services.openssh = {
    enable = true;
    ports = [ config.hostSpec.sshPort ];
    settings = {
      PasswordAuthentication = false;
      AllowUsers = null;
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  # TODO: Build this list from somewhere i.e. sops
  users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBlx7O+cDYGgMExuOgIKQjUvOiSSQMIaHnwqpqUye8b beau@arch" # grill
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDi27VjcR3I1rSTHfp3JvOZw1HQv1fCSTjIiob4cLa6q JuiceSSH" # galaxy s9
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiMXGI4mXg1Aw/gvx9LH5wEYMJ0M0ZgVKtoUZioaWfH beau@nixos" # laptop
  ];

  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.ssh 0700 ${config.hostSpec.username} users - -"
  ];
  sops.secrets = {
    "ssh/${config.networking.hostName}/priv" = {
      path = "${config.hostSpec.home}/.ssh/id_ed25519";
      mode = "0600";
      owner = config.hostSpec.username;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
}
