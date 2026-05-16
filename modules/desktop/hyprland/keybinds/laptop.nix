{ ... }:
{
  hypr.launchers = [
    {
      key = "o";
      app = "ghostty --gtk-single-instance=false --title=grill -e ssh grill";
      workspace = "grill";
      title = "grill";
    }
  ];
}
