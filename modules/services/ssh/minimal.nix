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
  ];

  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.ssh 0700 ${config.hostSpec.username} users - -"
  ];

  hm.primary.programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      t480 = {
        hostname = "t480.lan";
        user = "beau";
      };
      laptop = {
        hostname = "laptop.lan";
        user = "beau";
      };
      rozzy = {
        hostname = "172.105.188.232";
        user = "beau";
      };
      roster = {
        hostname = "45.79.238.145";
        user = "beau";
      };
      grill = {
        hostname = "grill.lan";
        user = "beau";
      };
      nas = {
        hostname = "nas.lan";
        user = "beau";
      };
      agent = {
        hostname = "agent";
        user = "beau";
      };
      mcbrick = {
        user = "mikaerem";
      };
      pi4 = {
        hostname = "pi4.lan";
        user = "beau";
      };
      pizero = {
        hostname = "192.168.1.103";
        user = "pi";
        port = 22;
      };
      dad = {
        hostname = "slippers.beaudan.me";
        user = "steve";
        port = 9022;
      };
      m3 = {
        hostname = "m3.massive.org.au";
        user = "beaudanc";
      };
      "*" = {
        forwardAgent = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        compression = false;
      };
    };
  };
}
