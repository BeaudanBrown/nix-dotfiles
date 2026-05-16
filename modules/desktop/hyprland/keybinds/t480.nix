{ ... }:
{
  # TODO: This breaks for the minimal install
  hypr.windowsLauncher = {
    key = "v";
    app = "windows-vm-start && windows-vm-viewer";
    workspace = "Windows";
    class = "remote-viewer";
  };

  hypr.launchers = [
    {
      key = "o";
      app = "ghostty --gtk-single-instance=false --title=grill -e ssh grill";
      workspace = "grill";
      title = "grill";
    }
  ];
}
