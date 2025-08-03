{ ... }:
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      laptop = {
        hostname = "ssh.bepis.lol";
        port = 8023;
        user = "beau";
      };
      grill = {
        hostname = "ssh.bepis.lol";
        port = 8022;
        user = "beau";
      };
      nas = {
        hostname = "192.168.68.103";
        user = "beau";
        port = 8022;
      };
      pizero = {
        hostname = "192.168.1.103";
        user = "pi";
        port = 22;
      };
      pi4 = {
        hostname = "192.168.1.122";
        user = "beau";
        port = 8023;
      };
      dad = {
        hostname = "slippers.beaudan.me";
        user = "steve";
        port = 9022;
      };
      m3 = {
        hostname = "m3.massive.org.au";
        user = "beaudanc";
      };
    };
  };
}
