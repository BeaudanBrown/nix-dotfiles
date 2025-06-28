{ ... }:
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      nas = {
        hostname = "192.168.1.103";
        user = "beau";
      };
      pizero = {
        hostname = "192.168.1.103";
        user = "pi";
      };
      pi4 = {
        hostname = "192.168.1.122";
        user = "beau";
      };
      dad = {
        hostname = "slippers.beaudan.me";
        user = "steve";
      };
      m3 = {
        hostname = "m3.massive.org.au";
        user = "beaudanc";
      };
    };
  };
}
