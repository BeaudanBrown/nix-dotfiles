{ pkgs, ... }:
let
  hyprland_show_app = pkgs.writeShellScriptBin "hyprland_show_app" ''
usage() {
  echo "Usage: $0 -a APP_NAME [-c CLASS_NAME] [-p]"
  echo "  APP_NAME         Name of the app to show."
  echo "  CLASS_NAME       Optional class name if the app has a different window pid."
  echo "  -p               Pull option."
  exit 1
}

# Variables to hold argument values
APP_NAME=""
CLASS_NAME=""
PULL=false

# Parse optional flags
while getopts ":a:c:p" option; do
  case $option in
    a)
      APP_NAME=''${OPTARG}
      ;;
    c)
      CLASS_NAME=''${OPTARG}
      ;;
    p)
      PULL=true
      ;;
    ?)
      echo "Error: Invalid option -''${OPTARG}"
      usage
      ;;
  esac
done

echo "APP_NAME = $APP_NAME"
echo "CLASS_NAME = $CLASS_NAME"
echo "PULL = $PULL"
# Ensure there's at least one positional parameter
if [ -z $APP_NAME ]; then
  echo "Error: APP_NAME is missing."
  usage
fi

PID_PATH="/tmp/$APP_NAME"

launch_app() {
	# TODO: Check if there is a conflicting app already open
	echo "Launching $APP_NAME"
  CUR_WORKSPACE_NAME=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.name')

  echo "$CUR_WORKSPACE_NAME"
  echo "$APP_NAME"

  if [ "$PULL" = false ] && [ "$CUR_WORKSPACE_NAME" != "$APP_NAME" ]; then
    echo "Launching on app workspace"
    hyprctl dispatch exec "[workspace name:$APP_NAME] $APP_NAME"
  else
    echo "Launching app where it is"
    $APP_NAME
  fi
	return 0
}

if [ -f "$PID_PATH" ]; then
  APP_PID=`cat $PID_PATH`
  echo "File $PID_PATH exists with contents $APP_PID"
fi

WINDOW_ID=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r --arg pid "$APP_PID" '.[] | select(.pid == ($pid | tonumber)) | .id')

if [[ -z "$WINDOW_ID" ]]; then
	APP_PID=""
	rm $PID_PATH
  echo "Can't find window with that pid"
  if [[ ! -z $CLASS_NAME ]]; then
    echo "Searching by classname"
    APP_PID=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r --arg class_name "$CLASS_NAME" '.[] | select(.class == $class_name) | .pid' | tail -n1)
  else
    echo "Searching by appname"
    APP_PID=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r --arg class_name "$APP_NAME" '.[] | select(.class == $class_name) | .pid' | tail -n1)
  fi
  if [[ -z $APP_PID ]]; then
    echo "Couldn't find window by classname or none provided, launching app"
    launch_app
    exit 0
  fi
  echo "Found window via classname"
	echo "$APP_PID" > "$PID_PATH"
fi

echo "Process exists"

#App is open somewhere
CUR_WORKSPACE_NAME=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq '.name')
CUR_WORKSPACE_ID=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq '.id')
APP_WORKSPACE=$(hyprctl clients -j | ${pkgs.jq}/bin/jq --arg APP_PID "$APP_PID" \
  '.[] | select(.pid == ($APP_PID | tonumber)) | .workspace.name')

echo "Current workspace is $CUR_WORKSPACE_NAME"
echo "App workspace is $APP_WORKSPACE"

if [ "$PULL" = false ]; then
  echo "Sending app to its workspace and toggling the workspace"
  hyprctl dispatch workspace name:$APP_NAME
  hyprctl dispatch movetoworkspacesilent name:$APP_NAME,pid:$APP_PID
  exit 0
fi


echo "Pull enabled"

if [ "$CUR_WORKSPACE_NAME" == "$APP_NAME" ]; then
  echo "We are on the app workspace"
  if [ "$APP_WORKSPACE" == "$APP_NAME" ]; then
    echo "Send all other apps away"
  else
    echo "Bring him home"
    hyprctl dispatch movetoworkspacesilent name:$APP_NAME,pid:$APP_PID
  fi
else
  echo "We are on some other workspace"
  if [ "$APP_WORKSPACE" == "$CUR_WORKSPACE_NAME" ]; then
    echo "Send him home"
    hyprctl dispatch movetoworkspacesilent name:$APP_NAME,pid:$APP_PID
  else
    echo "Bring him here"
    hyprctl dispatch movetoworkspacesilent e-0,pid:$APP_PID
  fi
fi
'';

in
{
  environment.systemPackages = [
    hyprland_show_app
  ];
}
