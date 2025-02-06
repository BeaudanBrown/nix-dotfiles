{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.audio;
in
{
  options.${namespace}.hardware.audio = with types; {
    enable = mkBoolOpt false "Whether or not to enable audio.";
  };

  config = mkIf cfg.enable {
    security.rtkit.enable = true;

    # pipewire = {
    #   enable = true;
    #   audio.enable = true;
    #   pulse.enable = true;
    #   alsa = {
    #     enable = true;
    #     support32Bit = true;
    #   };
    # };

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
    dotfiles.user.extraGroups = [ "audio" ];
    environment.systemPackages = with pkgs; [
      pavucontrol
    ];
  };
}
