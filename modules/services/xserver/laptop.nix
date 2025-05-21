{ config, ... }:
{
  services.xserver.videoDrivers = if config.hostSpec.isBootstrap then [ ] else [ "displaylink" ];
}
