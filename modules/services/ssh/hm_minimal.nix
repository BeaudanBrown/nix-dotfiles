{ ... }:
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      nas = {
        hostname = "192.168.1.103";
        user = "root";
      };
    };
  };
}
