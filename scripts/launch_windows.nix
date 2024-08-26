{ pkgs, ... }:
let
  launch_windows = pkgs.writeShellScriptBin "launch_windows" ''
    VBoxManage startvm "Windows"
'';

in
{
  environment.systemPackages = [
    launch_windows
  ];
}
