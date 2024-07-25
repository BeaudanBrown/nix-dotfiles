{ pkgs, ... }:
let
  bspwm_external_rules = pkgs.writeShellScriptBin "bspwm_external_rules" ''
id=''${1?} \
class=$2
instance=$3 \
border= \
center= \
desktop= \
focus= \
follow= \
hidden= \
layer= \
locked= \
manage= \
marked= \
misc=$4 \
monitor= \
node= \
private= \
rectangle= \
split_dir= \
split_ratio= \
state= \
sticky= \
urgent=;

read -r x_pixels y_pixels <<<$(${pkgs.xorg.xdpyinfo}/bin/xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+)x([0-9]+).*$/\1 \2/')
Xaxis=$(expr $(${pkgs.xorg.xrandr}/bin/xrandr --current | grep '\*' | uniq | awk '{print $1}' | cut -d 'x' -f1) \* 10 / 10)
Yaxis=$(expr $(${pkgs.xorg.xrandr}/bin/xrandr --current | grep '\*' | uniq | awk '{print $1}' | cut -d 'x' -f2) \* 10 / 10)
echo $Xaxis
echo $Yaxis
# { read mainmonitor ; read secondmonitor ; } <<< $(bspc query --monitors --names)

spotify() {
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
    sticky=on
}

caprine() {
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
    sticky=on
}

timer() {
    rectangle=$(expr 2 \* $(echo $Xaxis) / 5)x$(expr $(echo $Yaxis) / 3)+0+0
    center=on
    state=floating
    sticky=on
}

nemo() {
    rectangle=$(expr $(echo $Xaxis) / 2)x$(expr $(echo $Yaxis) / 2)+0+0
    center=on
    state=floating
    sticky=on
}

signal() {
    sticky=on
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
}

discord() {
    sticky=on
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
}

telegram() {
    sticky=on
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
}

steam() {
    sticky=on
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
}

obs() {
    sticky=on
    rectangle=$(echo $Xaxis)x$(echo $Yaxis)+0+0
    center=on
    state=floating
}

case $instance.$class in
    (*.Signal) signal;;
    (*.Spotify) spotify;;
    (*.caprine) caprine;;
    (*.Caprine) caprine;;
    (*.discord) discord;;
    (*.TelegramDesktop) telegram;;
    (*.Steam) steam;;
    (*.nsc-pyrus-server) pyrus;;
    (*.obs) obs;;
    (*.timer) timer;;
    (*.Nemo) nemo;;
    (.)
        case $(ps -p "$(xdo pid "$id")" -o comm= 2>/dev/null) in
            (spotify) spotify;;
            (discord) discord;;
        esac;;
esac;

wmtitle=$(xtitle $1)
[[ $wmtitle = "Emulator" ]] && state=floating

echo \
    ''${border:+"border=$border"} \
    ''${center:+"center=$center"} \
    ''${desktop:+"desktop=$desktop"} \
    ''${focus:+"focus=$focus"} \
    ''${follow:+"follow=$follow"} \
    ''${hidden:+"hidden=$hidden"} \
    ''${layer:+"layer=$layer"} \
    ''${locked:+"locked=$locked"} \
    ''${manage:+"manage=$manage"} \
    ''${marked:+"marked=$marked"} \
    ''${monitor:+"monitor=$monitor"} \
    ''${node:+"node=$node"} \
    ''${private:+"private=$private"} \
    ''${rectangle:+"rectangle=$rectangle"} \
    ''${split_dir:+"split_dir=$split_dir"} \
    ''${split_ratio:+"split_ratio=$split_ratio"} \
    ''${state:+"state=$state"} \
    ''${sticky:+"sticky=$sticky"} \
    ''${urgent:+"urgent=$urgent"};
'';

in
{
  xsession.windowManager.bspwm = {
    enable = true;
    settings = {
      window_gap = 3;
      border_width = 5;
      top_padding = "-8px";
      bottom_padding = "50px";
      borderless_monocle = true;
      focus_follows_pointer = false;
      pointer_modifier = "mod4";
      pointer_action1 = "move";
      pointer_action2 = "resize_corner";
      external_rules_command = "${bspwm_external_rules}/bin/bspwm_external_rules";
    };
  };

  services.sxhkd = {
    enable = true;
    keybindings = {
      "super + {_, shift + }q" = "bspc node -{c,k}";
      "super + {h,j,k,l}" = "bspc node -f {west,south,north,east}";
      "super + {shift + space,f}" = "bspc node -t '~{floating,fullscreen}'";
      "super + shift + r" = "bspc wm -r";
      "super + Tab" = "bspwm_dynamic_desktops --df $(bspc query -D -d --names)";
      "super + {_,shift +} grave" = "bspc desktop -f {next,prev}.local";
      "super + shift + {h,j,k,l}" = "bspwm_node_move {west,south,north,east}";
      "super + {_,shift + ,ctrl + shift +,ctrl +}{0-9}" = "bspwm_dynamic_desktops {--df,--ns,--nm,--da} {0-9}";

      "super + Return" = "$TERMINAL";
      "super + w" = "brave";
      "super + space" = "rofi -show run";
      "super + shift + x" = "bspc quit";
      "super + m" = "bspwm_toggle_scratch_prog 'spotify' 'spotify' 'Spotify'";
    };
  };

  home.packages = [
    bspwm_external_rules
  ];
}
