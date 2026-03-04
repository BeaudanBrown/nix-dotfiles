{ ... }:
{
  services.deskflow = {
    enable = true;
    role = "server";
    screens = [
      "grill"
      "t480"
    ];
    screenLinks = {
      grill = {
        left = "t480";
      };
      t480 = {
        right = "grill";
      };
    };
  };
}
