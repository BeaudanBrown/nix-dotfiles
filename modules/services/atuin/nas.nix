{ config, ... }:
let
  portKey = "atuin";
in
{
  services.atuin = {
    enable = true;
    host = "0.0.0.0";
    port = config.custom.ports.assigned.${portKey};
    openFirewall = true;
    openRegistration = true;
  };
}
