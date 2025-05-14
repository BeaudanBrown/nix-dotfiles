{
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    libnotify
    (import ./scripts/hyprland_show_app.nix { inherit pkgs; })
  ];
  programs.light.enable = true;
  users.users.${config.hostSpec.username}.extraGroups = [ "video" ];

  programs.hyprland.enable = true;
  services.xserver = {
    enable = true;
    autoRepeatDelay = 175;
    autoRepeatInterval = 50;
    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
    };
    xkb = {
      layout = "au";
      variant = "";
      options = "caps:escape";
    };
  };
}
