{ ... }:
{
  hypr.launchers = [
    {
      key = "o";
      app = "ghostty --gtk-single-instance=false --title=t480 -e ssh t480";
      workspace = "t480";
      title = "t480";
    }
  ];
}
