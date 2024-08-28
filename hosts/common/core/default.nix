{ inputs, pkgs, configLib, ... }:
{
  imports = configLib.scanPaths (configLib.relativeToRoot "scripts") ++
  (configLib.scanPaths ./.);

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

  boot.loader = {
    timeout = 1;
    systemd-boot = {
      configurationLimit = 10;
      enable = true;
    };
  };

  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 16*1024;
  } ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  programs.waybar.enable = true;

  fonts.packages = with pkgs; [
    jetbrains-mono
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  services.blueman.enable = true;

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
    xkb.options = "caps:escape";
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
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
}
