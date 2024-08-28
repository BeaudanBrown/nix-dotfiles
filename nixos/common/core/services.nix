{ ... }:
{
  services = {
    xserver = {
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

    printing.enable = true;
    blueman.enable = true;

    udisks2 = {
      enable = true;
      mountOnMedia = true;
    };

    pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
  };
}
