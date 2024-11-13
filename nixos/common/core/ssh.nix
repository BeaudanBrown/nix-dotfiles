{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      AllowUsers = null;
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users."beau".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBlx7O+cDYGgMExuOgIKQjUvOiSSQMIaHnwqpqUye8b beau@arch" # grill
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDi27VjcR3I1rSTHfp3JvOZw1HQv1fCSTjIiob4cLa6q JuiceSSH" # galaxy s9
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiMXGI4mXg1Aw/gvx9LH5wEYMJ0M0ZgVKtoUZioaWfH beau@nixos" # laptop
  ];
}
