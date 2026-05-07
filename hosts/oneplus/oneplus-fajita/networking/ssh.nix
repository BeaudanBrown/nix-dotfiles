{ ... }:
let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIGq7BtN17qkaJce/2iMjrDvdfp6wloSYylzbZVJLSUu" # root
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkCzAuXbRvn9rtl2wgHIxNYN6A3YeJ/w04Itm7Ck3V beau@nas" # nas
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBlx7O+cDYGgMExuOgIKQjUvOiSSQMIaHnwqpqUye8b beau@arch" # grill
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL472wjBWlBbL8yLBSwPXorccKJ4JZcfmtEO7iqVTfo1 beau@t480" # agent/t480 key
  ];
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitEmptyPasswords = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.beau.openssh.authorizedKeys.keys = authorizedKeys;
}
