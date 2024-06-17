# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    cores = 12;
  };
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = _: true;
  imports =
    [
      ./hardware-configuration.nix
      ./nvidia.nix
      ./tmux
      # ./services/greetd.nix
    ];

  programs.nixvim = import ./nixvim/config/default.nix;

  fonts.packages = with pkgs; [
    jetbrains-mono
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  # Enable networking
  networking.networkmanager.enable = true;

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

  services.xserver = {
    enable = true;
    xkb.layout = "au";
    xkb.variant = "";
    autoRepeatDelay = 175;
    autoRepeatInterval = 50;
    desktopManager.xfce = {
      enable = true;
      enableXfwm = false;
      noDesktop = true;
      enableScreensaver = false;
    };
    # displayManager.sx.enable = true;
    # windowManager.bspwm = {
      # enable = true;
      # configFile = "/home/beau/.config/bspwm/bspwmrc";
      # sxhkd.configFile = "/home/beau/.config/sxhkd/sxhkdrc";
    # };
  };
  # services.displayManager = {
  #   sddm.enable = true;
  # };

  services.printing.enable = true;

  services.udisks2 = {
    enable = true;
    mountOnMedia = true;
  };

  sound.enable = true;
  hardware.pulseaudio.enable = false;


  hardware.bluetooth.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users.beau = {
      isNormalUser = true;
      description = "Beaudan";
      extraGroups = [ "networkmanager" "wheel" ];
    };
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.shells = [ pkgs.zsh ];
  environment.shellAliases = {
    vim = "nvim";
    sudo = "sudo ";
    nc = "sudo vim /etc/nixos/configuration.nix";
    nr = "sudo nixos-rebuild switch";
  };


  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
    TERMINAL = "kitty";
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    htop
    brave
    vlc
    zathura
    spotify
    qbittorrent
    oh-my-posh
    tor-browser-bundle-bin
    calibre
    wezterm
    kitty
  ];

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
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    histSize = 10000;
    ohMyZsh = {
      enable = true;
      # plugins = [
      #   "autojump"
      #   "starship"
      #   "fzf"
      # ];
    };
    # promptInit = ''
    #   eval "$(oh-my-posh init zsh --config ${./extraConfig/oh-my-posh.toml})"
    # '';
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
