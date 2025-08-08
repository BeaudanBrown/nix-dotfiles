{
  pkgs,
  config,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    libreoffice
  ];

  home-manager.users.${config.hostSpec.username}.xdg = {
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
