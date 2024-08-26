# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    substituters = [
      "https://hyprland.cachix.org"
    ];
    trusted-substituters = [
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];

    cores = 12;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = _: true;

  imports = let
    scriptFolder = ./scripts;
    files = builtins.attrNames (builtins.readDir scriptFolder);
    scriptFiles = map (file: "${scriptFolder}/${file}") files;
  in
  [
  ] ++ scriptFiles;

  programs.nixvim = import ./nixvim/config/default.nix;

  fonts.packages = with pkgs; [
    jetbrains-mono
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];
  boot.loader.systemd-boot = {
    configurationLimit = 5;
    enable = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    #TODO: make this device independent
    hostName = "grill";
  };

  # Enable networking
  networking.networkmanager = {
    enable = true;
    plugins = [
      pkgs.networkmanager-openconnect
    ];
  };

  # Set your time zone.
  time.timeZone = "Australia/Melbourne";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  i18n.extraLocaleSettings = {
    LANG = "en_AU.UTF-8";
    LC_ALL = "en_AU.UTF-8";
    LANGUAGE = "en_AU.UTF-8";
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  services.blueman.enable = true;

  services.samba = {
    enable = true;
  };

  services.xserver = {
    enable = true;
    xkb.layout = "au";
    xkb.variant = "";
    autoRepeatDelay = 175;
    autoRepeatInterval = 50;
    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
    };
    desktopManager.gnome = {
      enable = false;
    };
    xkb.options = "caps:escape";
  };
  services.displayManager.defaultSession = "hyprland";
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    xwayland.enable = true;
  };

  console.useXkbConfig = true;

  services.printing.enable = true;

  services.udisks2 = {
    enable = true;
    mountOnMedia = true;
  };

  hardware.bluetooth.enable = true;

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command =  "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "beau";
    dataDir = "/home/beau";
    settings = {
      options = {
        urAccepted = -1;
      };
      devices = {
        "server" = {
          id = "YZLDZHW-7MYKYEM-5PTTWLU-TBPEQJX-CJEFVBS-UYIOQJM-OKCQ723-25HTDAT";
          autoAcceptFolder = true;
        };
        "nix-laptop" = {
          id = "T2YY6AY-XQNZQQW-RRI52RN-EARJZHR-6GPNA2A-2QBRMFD-TOHY5SH-MXFKVAC";
          autoAcceptFolder = true;
        };
        "grill" = {
          id = "B4SXNGB-I6QC6RM-GCPSPXR-JSCTBNJ-RTFDNVW-OPVO3TB-BQ7EDSO-ODJV4AC";
          autoAcceptFolder = true;
        };
      };
      folders."documents" = {
        id = "txxit-w9cwz";
        path = "~/documents";
        devices = [ "server" "grill" "nix-laptop" ];
      };
      folders."monash" = {
        id = "twjfr-ekoqc";
        path = "~/monash";
        devices = [ "server" "grill" "nix-laptop" ];
      };
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    extraGroups.vboxusers.members = ["beau"];
    users.beau = {
      isNormalUser = true;
      description = "Beaudan";
      extraGroups = [ "video" "audio" "networkmanager" "wheel" "docker" ];
    };
  };

  environment = {
    shells = [ pkgs.zsh ];
    shellAliases = {
      vim = "nvim";
      sudo = "sudo ";
      nc = "vim ~/documents/nix-dotfiles/configuration.nix";
      nr = "sudo nixos-rebuild switch";
      ls = "${pkgs.eza}/bin/eza -lh --group-directories-first";
      cat = "${pkgs.bat}/bin/bat";
      man = "${pkgs.bat-extras.batman}/bin/batman ";
      sd="sudo mount -t cifs -o credentials=/home/beau/.config/smbcredentials,uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,soft,cache=none //ad.monash.edu/shared /s" ;
    };
    sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
      TERMINAL = "kitty";
    };
    variables = {
    };
    systemPackages = with pkgs; [
      # samba stuff
      cifs-utils
      keyutils

      okular
      nh

      networkmanager-openconnect
      ripgrep
      acpi
      bind
      libreoffice
      duc
      cryptsetup
      inkscape
      slack
      zoom-us
      networkmanagerapplet
      openconnect
      wl-clipboard
      htop
      brave
      vlc
      zathura
      spotify
      qbittorrent
      calibre
      pciutils
      pavucontrol
      unzip
      xdotool
      devenv
      jq
      nautilus
      sxiv
      spotify
      xorg.xprop
      bat
      wofi
      signal-desktop
      eww
    ];
  };
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  programs.light.enable = true;

  programs.waybar = {
    enable = true;
  };

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Beaudan Brown";
        email = "beaudan.brown@gmail.com";
      };
    };
  };

  programs.fzf.keybindings = true;
  programs.autojump.enable = true;

  programs.zsh.enable = true;

  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 16*1024;
  } ];

  virtualisation = {
    virtualbox = {
      guest = {
        # Enabling this causes slow rebuild (potentially hanging while waiting for credentials?)
        enable = false;
        dragAndDrop = true;
      };
      host = {
        enable = true;
      };
    };
    docker = {
      enable = true;
      autoPrune = { enable = true; };
    };
  };

  stylix = {
    enable = true;
    image = ./bg.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa.yaml";

    targets.grub.useImage = true;
    targets.nixvim.enable = false;
    targets.gnome.enable = false;

    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerdfonts;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sizes = {
        applications = 14;
        terminal = 12;
      };
    };
    cursor = {
      package = pkgs.quintom-cursor-theme;
      name = "Quintom_Ink";
      size = 24;
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  # Required to mount cifs
  # https://github.com/NixOS/nixpkgs/issues/34638
  system.activationScripts.symlink-requestkey = ''
  if [ ! -d /sbin ]; then
    mkdir /sbin
  fi
  ln -sfn /run/current-system/sw/bin/request-key /sbin/request-key
  '';
  environment.etc."request-key.conf" = {
    text = let
      upcall = "${pkgs.cifs-utils}/bin/cifs.upcall";
      keyctl = "${pkgs.keyutils}/bin/keyctl";
    in ''
        #OP     TYPE          DESCRIPTION  CALLOUT_INFO  PROGRAM
        # -t is required for DFS share servers...
        create  cifs.spnego   *            *             ${upcall} -t %k
        create  dns_resolver  *            *             ${upcall} %k
        # Everything below this point is essentially the default configuration,
        # modified minimally to work under NixOS. Notably, it provides debug
        # logging.
        create  user          debug:*      negate        ${keyctl} negate %k 30 %S
        create  user          debug:*      rejected      ${keyctl} reject %k 30 %c %S
        create  user          debug:*      expired       ${keyctl} reject %k 30 %c %S
        create  user          debug:*      revoked       ${keyctl} reject %k 30 %c %S
        create  user          debug:loop:* *             |${pkgs.coreutils}/bin/cat
        create  user          debug:*      *             ${pkgs.keyutils}/share/keyutils/request-key-debug.sh %k %d %c %S
        negate  *             *            *             ${keyctl} negate %k 30 %S
        '';
      };

  # networking.openconnect.interfaces = {
  #   post = {
  #     user = "beaudan.campbell-brown@monash.edu.au";
  #     protocol = "anyconnect";
  #     gateway = "vpn.monash.edu";
  #     extraOptions = {
  #       token-mode = "totp";
  #     };
  #   };
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
