{
  pkgs,
  config,
  ...
}:
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
  users.users.${config.hostSpec.username}.extraGroups = [ "audio" ];
  environment.systemPackages = with pkgs; [
    pavucontrol
  ];
}
