{ config, pkgs, inputs, ... }:
let
  bspwm_toggle_scratch_node = pkgs.writeShellScriptBin "bspwm_toggle_scratch_node" ''
[[ -z $1 ]] && exit
nodeID=$1

currentNode=$(bspc query -n focused -N | tr a-z A-Z)
echo [[ $currentNode = $nodeID ]]

if [[ -z $(bspc query -n $nodeID.hidden -N) ]]; then
    # Not hidden
    echo "Hiding"
    bspc node $nodeID -g hidden=true
else
    # Hidden
    echo "Focussing node"
    echo $nodeID
    bspc node $nodeID -g hidden=false -f
    fi
  '';

  bspwm_toggle_scratch_prog = pkgs.writeShellScriptBin "bspwm_toggle_scratch_prog" ''
[[ -z $1 ]] && exit
[[ -z $2 ]] && exit
[[ -z $3 ]] && exit
appName=$1
className1=$2
className2=$3
flags=$4

if ! ${pkgs.wmctrl}/bin/wmctrl -lx | grep -q -i $className1.$className2; then
  # App isn't open
  echo 'Opening app'
  $appName $flags
  sleep 2
else
    # App is open
    nodeID=$(${pkgs.wmctrl}/bin/wmctrl -lx | awk "/$className1.$className2/ {print toupper(\$1)}")
    ${bspwm_toggle_scratch_node}/bin/bspwm_toggle_scratch_node $nodeID
fi
'';

in
{
  environment.systemPackages = [
    bspwm_toggle_scratch_prog
  ];
}

