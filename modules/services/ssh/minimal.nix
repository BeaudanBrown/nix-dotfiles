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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIGq7BtN17qkaJce/2iMjrDvdfp6wloSYylzbZVJLSUu" # root
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkCzAuXbRvn9rtl2wgHIxNYN6A3YeJ/w04Itm7Ck3V beau@nas" # nas
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBlx7O+cDYGgMExuOgIKQjUvOiSSQMIaHnwqpqUye8b beau@arch" # grill
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDi27VjcR3I1rSTHfp3JvOZw1HQv1fCSTjIiob4cLa6q JuiceSSH" # galaxy s9
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiMXGI4mXg1Aw/gvx9LH5wEYMJ0M0ZgVKtoUZioaWfH beau@nixos" # laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN3T4/Ob/aFlKn3aIX29r6LZ8baeMLWAQxQtXeV5g5Br beaudan.brown@gmail.com" # pi4
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL472wjBWlBbL8yLBSwPXorccKJ4JZcfmtEO7iqVTfo1 beau@t480" # agent/t480 key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBYWJcI/KdO1Nile/OUEaFuwVannPk7PJMG5P+i9inb beau@nixos" # rozzy
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINWJxY8ri0vZBbk6GXwWGV1PuHjxeN3G938fq+ZfEWyH lachy@nixos" # lachy vm
  ];

  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.ssh 0700 ${config.hostSpec.username} users - -"
  ];

  hm.primary.programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      t480 = {
        HostName = "t480.lan";
        User = "beau";
      };
      laptop = {
        HostName = "laptop.lan";
        User = "beau";
      };
      rozzy = {
        HostName = "172.105.188.232";
        User = "beau";
      };
      roster = {
        HostName = "45.79.238.145";
        User = "beau";
      };
      grill = {
        HostName = "grill.lan";
        User = "beau";
      };
      nas = {
        HostName = "nas.lan";
        User = "beau";
      };
      agent = {
        HostName = "agent";
        User = "beau";
      };
      mcbrick = {
        User = "mikaerem";
      };
      pi4 = {
        HostName = "pi4.lan";
        User = "beau";
      };
      pizero = {
        HostName = "192.168.1.103";
        User = "pi";
        Port = 22;
      };
      dad = {
        HostName = "slippers.beaudan.me";
        User = "steve";
        Port = 9022;
      };
      m3 = {
        HostName = "m3.massive.org.au";
        User = "beaudanc";
      };
      "*" = {
        ForwardAgent = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        Compression = false;
      };
    };
  };
}
