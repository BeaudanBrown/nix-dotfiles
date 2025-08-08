{ pkgs, config, ... }:
let
  script = ''

    if [ $# -ne 0 ]
    then
        coproc nautilus "$1" > /dev/null  2>&1
        exit 0
    fi
    find "$HOME" -maxdepth 5 -type d -not -path '*/\.*' 2>/dev/null | sed "s|^$HOME/||"

  '';

  rofi_launch_dir = pkgs.writeShellApplication {
    name = "rofi_launch_dir";
    text = script;
  };
in
{
  home-manager.users.${config.hostSpec.username}.home.packages = [
    rofi_launch_dir
  ];
}
