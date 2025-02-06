{ options
, config
, pkgs
, lib
, namespace
, ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.boot;
in
{
  options.${namespace}.system.boot = with types; {
    enable = mkBoolOpt true "Whether or not to manage boot configueration.";
  };

  config = mkIf cfg.enable {
    boot = {
      supportedFilesystems = [ "ntfs" ];
      kernelPackages = pkgs.linuxPackages_latest;
      kernelParams = [
        "snd-intel-dspcfg.dsp_driver=1"
        "kvm.enable_virt_at_load=0"
      ];
      loader = {
        timeout = 1;
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          configurationLimit = 10;
        };
      };
    };
  };
}
