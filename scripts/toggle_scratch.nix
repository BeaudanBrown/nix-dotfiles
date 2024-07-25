{ config, pkgs, inputs, ... }:
let
  toggle_scratch = pkgs.writeShellScriptBin "toggle_scratch" ''
# Define the application command and window class
APP_COMMAND="$1"
APP_CLASS="$2"

# Get the window ID of the application if it's already running
WIN_ID=$(xdotool search --class "$APP_CLASS")

# If no window is found, launch the application
if [ -z "$WIN_ID" ]; then
    # Launch the application
    "$APP_COMMAND" &
    exit
fi

# Toggle the visibility of the application window
if bspc query -N -n .window.hidden | grep -q "^''${WIN_ID}$"; then
    bspc node "$WIN_ID" --flag hidden=off
else
    bspc node "$WIN_ID" --flag hidden=on
fi
'';

in
{
  environment.systemPackages = [
    toggle_scratch
  ];
}




