{ inputs, pkgs, configLib, ... }:
{
  imports = (configLib.scanPaths ./.);

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
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];
    loader = {
      timeout = 1;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16*1024;
    }
  ];

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

  fonts.packages = with pkgs; [
    jetbrains-mono
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  };

  console.useXkbConfig = true;

  hardware.bluetooth.enable = true;

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam.services.hyprlock = {};
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

  environment = {
    shells = [ pkgs.zsh ];
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

      # Network
      networkmanager-openconnect
      networkmanagerapplet
      openconnect

      # Applications
      caprine
      brave
      vlc
      zathura
      spotify
      qbittorrent
      nautilus
      calibre
      libreoffice
      inkscape
      slack
      zoom-us
      sxiv
      signal-desktop
      okular

      # Utilities
      ripgrep
      wl-clipboard
      htop
      pavucontrol
      duc
      nh
      acpi
      bind
      pciutils
      unzip
      devenv
      jq
      bat
      wofi
      eww
      grim
      slurp

      # TODO: device specific
      cryptsetup
      xdotool
      xorg.xprop
    ];
  };

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

  programs.light.enable = true;

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Beaudan Brown";
        email = "beaudan.brown@gmail.com";
      };
    };
  };

  programs.autojump.enable = true;

  programs.zsh.enable = true;
  programs.kdeconnect.enable = true;
}
