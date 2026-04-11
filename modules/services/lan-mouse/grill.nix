{ lib, ... }:
{
  services = {
    deskflow.enable = lib.mkForce false;
    lanMouse = {
      enable = true;
      clients = [
        {
          position = "left";
          hostname = "t480";
          ips = [ "100.64.0.7" ];
        }
      ];
    };
  };
}
