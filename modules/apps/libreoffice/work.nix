{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    libreoffice
  ];

  hm.xdg = {
    mimeApps = {
      enable = true;
      # to see available > ls /run/current-system/sw/share/applications/
      defaultApplications = {
        "application/msword" = [ "writer.desktop" ];
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "writer.desktop" ];
      };
    };
  };
}
