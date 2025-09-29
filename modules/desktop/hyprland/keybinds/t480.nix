{ ... }:
{
  # TODO: This breaks for the minimal install
  hypr.launchers = [
    {
      key = "o";
      app = "kitty --class=grill ssh grill";
      workspace = "grill";
      class = "grill";
    }
  ];
}
