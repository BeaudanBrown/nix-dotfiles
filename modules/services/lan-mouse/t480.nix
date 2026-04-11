{ lib, ... }:
{
  services = {
    deskflow.enable = lib.mkForce false;
    lanMouse = {
      enable = true;
      clients = [
        {
          position = "right";
          hostname = "grill";
          ips = [ "100.64.0.5" ];
        }
      ];
    };
  };
}
