{ pkgs, ... }:
let
  launch_windows = pkgs.writeShellApplication {
    name = "launch_windows";
    text = ''
      VBoxManage startvm "Windows"
    '';
  };
in
{
  environment.systemPackages = [
    launch_windows
  ];
}
