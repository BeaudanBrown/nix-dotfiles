{ config, ... }:
{
  hm.programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config = {
      whitelist = {
        prefix = [
          "${config.hostSpec.home}/documents"
          "${config.hostSpec.home}/monash"
          "${config.hostSpec.home}/collab"
        ];
      };
    };
  };
}
