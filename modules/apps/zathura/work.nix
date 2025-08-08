{ ... }:
{
  hm.xdg = {
    mimeApps = {
      enable = true;
      # to see available > ls /run/current-system/sw/share/applications/
      defaultApplications = {
        "application/pdf" = [
          "org.pwmt.zathura.desktop"
        ];
      };
    };
  };

  hm.programs.zathura = {
    enable = true;
    mappings = {
      "J" = "zoom out";
      "K" = "zoom in";
    };
    options = {
      selection-clipboard = "clipboard";
    };
  };
}
