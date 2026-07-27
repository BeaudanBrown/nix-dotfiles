{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleetInstaller = inputs.self.packages.x86_64-linux.fleet-installer;
  installHost = pkgs.writeShellApplication {
    name = "install-host";
    text = ''
      exec sudo ${fleetInstaller}/bin/fleet-installer install-host
    '';
  };
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.nixvim.nixosModules.nixvim
  ];

  nixpkgs = {
    config.allowUnfree = true;
    hostPlatform = "x86_64-linux";
  };
  networking = {
    hostName = "fleet-installer";
    networkmanager.enable = true;
    firewall = {
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/mapper/installer-root";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/INST_BOOT";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "uas"
        "usb_storage"
        "usbhid"
        "virtio_blk"
        "virtio_pci"
        "virtio_scsi"
        "xhci_pci"
      ];
      luks.devices.installer-root.device = "/dev/disk/by-label/INSTALLER_LUKS";
    };
    loader = {
      efi.canTouchEfiVariables = false;
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
      timeout = 2;
    };
    supportedFilesystems = [
      "btrfs"
      "ext4"
      "vfat"
    ];
  };

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    tailscale = {
      enable = true;
      openFirewall = true;
    };
    getty.autologinUser = "installer";
  };

  systemd.services.fleet-installer-headscale = {
    description = "Connect the fleet installer to Headscale";
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/var/lib/fleet-installer/headscale-auth-key";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale up --auth-key=file:/var/lib/fleet-installer/headscale-auth-key --login-server=https://hs.bepis.lol --accept-dns=true --accept-routes=true --hostname=fleet-installer";
    };
  };

  users = {
    mutableUsers = false;
    users = {
      root.hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
      installer = {
        isNormalUser = true;
        uid = 1000;
        group = "users";
        home = "/home/installer";
        shell = pkgs.zsh;
      };
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "installer" ];
      commands = [
        {
          command = "${fleetInstaller}/bin/fleet-installer install-host";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  programs = {
    zsh = {
      enable = true;
      shellInit = ''
        eval "$(${pkgs.starship}/bin/starship init zsh)"
        echo "Wi-Fi fallback: nmtui"
        echo "Install a detected fleet host: install-host"
      '';
    };
    nixvim = import ../../modules/cli/nixvim/config/nixvim.nix { inherit lib; };
  };

  environment = {
    systemPackages = with pkgs; [
      age
      cryptsetup
      efibootmgr
      git
      gptfdisk
      fleetInstaller
      installHost
      jq
      just
      nixos-install-tools
      openssh
      parted
      pciutils
      rsync
      sops
      ssh-to-age
      starship
      tailscale
      tmux
      usbutils
      vim
      yq-go
    ];
  };

  nix = {
    settings = {
      accept-flake-config = true;
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
    };
    package = pkgs.nixVersions.latest;
  };

  system.stateVersion = "26.05";
}
