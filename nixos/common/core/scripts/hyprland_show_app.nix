{ pkgs, ... }:
let
  hyprland_show_app = pkgs.writeShellApplication {
    name = "hyprland_show_app";
    runtimeInputs = with pkgs; [ jq ];
    text = ''

usage() {
  echo "Usage: $0 -a APP_NAME [-c CLASS_NAME] [-t TITLE] [-w WORKSPACE_NAME] [-p]"
  echo "  APP_NAME         Name of the app to show."
  echo "  CLASS_NAME       Optional class name if the app has a different window pid."
  echo "  TITLE            Optional title if the app has a different window pid."
  echo "  WORKSPACE_NAME   Optional workspace if the app has a weird binary."
  echo "  -p               Pull option."
  exit 1
}

# TODO: use the hyprland tag window feature

# Variables to hold argument values
APP_NAME=""
WORKSPACE_NAME=""
CLASS_NAME=""
TITLE=""
PULL=false

CUR_WORKSPACE_NAME=$(hyprctl activeworkspace -j | jq -r '.name')

# Parse optional flags
while getopts ":a:c:t:w:p" option; do
  case $option in
    a)
      APP_NAME=''${OPTARG}
      ;;
    c)
      CLASS_NAME=''${OPTARG}
      ;;
    t)
      TITLE=''${OPTARG}
      ;;
    w)
      WORKSPACE_NAME=''${OPTARG}
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

if [ -z "$WORKSPACE_NAME" ]; then
  WORKSPACE_NAME="$APP_NAME"
fi

echo "APP_NAME = $APP_NAME"
echo "CLASS_NAME = $CLASS_NAME"
echo "WORKSPACE_NAME = $WORKSPACE_NAME"
echo "TITLE = $TITLE"
echo "PULL = $PULL"
# Ensure there's at least one positional parameter
if [ -z "$APP_NAME" ]; then
  echo "Error: APP_NAME is missing."
  usage
fi

PID_PATH="/tmp/$WORKSPACE_NAME"

launch_app() {
	# TODO: Check if there is a conflicting app already open
	echo "Launching $APP_NAME"

  if [ "$PULL" = false ] && [ "$CUR_WORKSPACE_NAME" != "$WORKSPACE_NAME" ]; then
    echo "Launching on app workspace"
    hyprctl dispatch exec "[workspace name:$WORKSPACE_NAME] $APP_NAME"
  else
    echo "Launching app where it is"
    $APP_NAME
  fi
	return 0
}

if [ -f "$PID_PATH" ]; then
  APP_PID=$(cat "$PID_PATH")
  echo "File $PID_PATH exists with contents $APP_PID"
  WINDOW_ID=$(hyprctl clients -j | jq -r --arg pid "$APP_PID" '.[] | select(.pid == ($pid | tonumber)) | .id')
fi


if [[ -z "$WINDOW_ID" ]]; then
	APP_PID=""
	rm "$PID_PATH"
  echo "Can't find window with that pid"
  if [[ -n $CLASS_NAME ]]; then
    echo "Searching by classname"
    APP_PID=$(hyprctl clients -j | jq -r --arg class_name "$CLASS_NAME" '.[] | select(.class == $class_name) | .pid' | tail -n1)
  elif [[ -n $TITLE ]]; then
    echo "Searching by title"
    APP_PID=$(hyprctl clients -j | jq -r --arg title "$TITLE" '.[] | select(.title == $title) | .pid' | tail -n1)
  else
    echo "Searching by appname"
    APP_PID=$(hyprctl clients -j | jq -r --arg class_name "$APP_NAME" '.[] | select(.class == $class_name) | .pid' | tail -n1)
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
APP_WORKSPACE=$(hyprctl clients -j | jq -r --arg APP_PID "$APP_PID" \
  '.[] | select(.pid == ($APP_PID | tonumber)) | .workspace.name')

echo "Current workspace is $CUR_WORKSPACE_NAME"
echo "App workspace is $APP_WORKSPACE"

if [ "$CUR_WORKSPACE_NAME" == "$WORKSPACE_NAME" ]; then
  echo "We are on the apps designated workspace"
  if [ "$CUR_WORKSPACE_NAME" == "$APP_WORKSPACE" ]; then
    echo "The app is with us"
    if [ "$PULL" = false ]; then
      echo "Go to previous workspace"
      hyprctl dispatch workspace name:"$CUR_WORKSPACE_NAME"
    else
      echo "TODO send all other apps away"
    fi
  else
    echo "The app is not here, bring it back"
    hyprctl dispatch movetoworkspace name:"$CUR_WORKSPACE_NAME",pid:"$APP_PID"
    hyprctl dispatch focuswindow pid:"$APP_PID"
  fi
else
  echo "We are not on the apps designated workspace"
  if [ "$APP_WORKSPACE" == "$CUR_WORKSPACE_NAME" ]; then
    echo "The app is on our current workspace"
    if [ "$PULL" = false ]; then
      echo "Go with it to its workspace"
      hyprctl dispatch movetoworkspace name:"$WORKSPACE_NAME",pid:"$APP_PID"
      hyprctl dispatch focuswindow pid:"$APP_PID"
    else
      echo "Send it to its designated workspace"
      hyprctl dispatch movetoworkspacesilent name:"$WORKSPACE_NAME",pid:"$APP_PID"
    fi
  else
    echo "The app is on a different workspace"
    if [ "$PULL" = false ]; then
      echo "Go with it to its workspace"
      hyprctl dispatch movetoworkspace name:"$WORKSPACE_NAME",pid:"$APP_PID"
      hyprctl dispatch focuswindow pid:"$APP_PID"
    else
      echo "Bring it here"
      hyprctl dispatch movetoworkspace name:"$CUR_WORKSPACE_NAME",pid:"$APP_PID"
      hyprctl dispatch focuswindow pid:"$APP_PID"
    fi
  fi
fi

    '';
  };

in
{
  environment.systemPackages = [
    hyprland_show_app
  ];
}
