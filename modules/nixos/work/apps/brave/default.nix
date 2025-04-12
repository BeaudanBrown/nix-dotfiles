{
  pkgs,
  ...
}:
{
  environment = {
    systemPackages = [ pkgs.brave ];
    variables.BROWSER = "brave";
  };
  home-manager.sharedModules = [
    {
      xdg = {
        mimeApps = {
          enable = true;
          # to see available > ls /run/current-system/sw/share/applications/
          defaultApplications = {
            "x-scheme-handler/http" = [ "brave-browser.desktop" ];
            "x-scheme-handler/https" = [ "brave-browser.desktop" ];
          };
        };
      };
    }
  ];
}
