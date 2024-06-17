{ pkgs, ... }: {
  xsession.windowManager.bspwm = {
    enable = true;
    # extraConfig = ''
# # Alias
# _bc() {
  # bspc config "$@"
# }

# # If refreshing bspwm, remove all previous rules to prevent doubling up.
# bspc rule -r "*"

# { read mainmonitor ; read secondmonitor ; } <<< $(bspc query --monitors --names)

# # Start workspaces on the main monitor.
# bspc monitor $mainmonitor -d 1
# [[ $secondmonitor ]] && bspc monitor $secondmonitor -d 6

# # If you want a multi-monitor display or something else, I leave that to you to
# # arrange. I have this sensible default for most people's use cases.

# _bc window_gap 5
# _bc border_width 3
# _bc top_padding -9px
# _bc bottom_padding 25px

# _bc borderless_monocle   true
# _bc focus_follows_pointer false
# _bc active_border_color '#707880'
# _bc normal_border_color '#282a2e'
# _bc focused_border_color '#81a2be'
# _bc ignore_ewmh_fullscreen all

# _bc pointer_modifier mod4
# _bc pointer_action1 move
# _bc pointer_action2 resize_corner
    # '';
  };
  services.sxhkd = {
    enable = true;
    extraConfig = ''
# Close node
super + {_, shift + }q
  bspc node -{c,k}
# Select node in direction
super + {h,j,k,l}
  bspc node -f {west,south,north,east}
super + {shift + space,f}
  bspc node -t '~{floating,fullscreen}'
super + shift + {s}
  bspc node {-g sticky -l above}
# Resize node in the given direction.
super + shift + {y,u,i,o}
  bspwm_node_resize {west,south,north,east} 20
# Swap current window with the biggest one in the present desktop
super + shift + b
  bspc node -s biggest.local
# Quit/restart bspwm
super + shift + r
  bspc wm -r
super + Escape
  bspwm_close
# Rotate orientation
super + o
    bspc node @parent -R 90
# Toggle between most recent workspaces
super + Tab
  bspwm_dynamic_desktops --df $(bspc query -D -d --names)
super + {_,shift +} grave
  bspc desktop -f {next,prev}.local
super + shift + {h,j,k,l}
  bspwm_node_move {west,south,north,east}
super + {_,shift + ,ctrl + shift +,ctrl +}{0-9}
  ;bspwm_dynamic_desktops {--df,--ns,--nm,--da} {0-9}
super + x
  betterlockscreen --off 5 -l

# Basic binds
super + Return
  starttmux
super + shift + Return
  $TERMINAL
super + space
  dmenu_run
super + r
  nemo
super + shift + f
  bspwm_toggle_scratch_prog "caprine" "caprine" "Caprine"
super + c
  bspwm_toggle_scratch_prog "signal-desktop" "signal" "Signal"
super + m
  bspwm_toggle_scratch_prog "spotify" "spotify" "Spotify"
super + d
  bspwm_toggle_scratch_prog "discord-canary" "discord" "discord"
super + o
  bspwm_toggle_scratch_prog "obs" "obs" "obs" "--startreplaybuffer"
super + shift + g
  bspwm_toggle_scratch_prog "steam" "Steam" "Steam"
super + t
  bspwm_toggle_scratch_prog "telegram-desktop" "telegram-desktop" "TelegramDesktop"
super + shift + m
  mute_audio
super + shift + n
  mute_mic
super + shift + p
  dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause &>/dev/null
super + comma
  dbus-send --print-reply  --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Previous &>/dev/null
super + period
  dbus-send --print-reply  --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Next &>/dev/null
super + i
  $TERMINAL -e htop
super + shift a
  switchaudio
super + a
  $TERMINAL -e pulsemixer; pkill -RTMIN+10 i3blocks
super + w
  $BROWSER
super + y
  clipmenu

# Et cetera...
super + shift + x
  prompt "Shutdown computer?" "systemctl poweroff"
super + shift + w
  prompt "Reboot into windows?" "windows_reboot"
super + shift + BackSpace
  prompt "Reboot computer?" "systemctl reboot"
XF86Launch1
  xset dpms force off
XF86AudioMute
  lmc mute
XF86AudioLowerVolume
  lmc down 5
shift+XF86AudioLowerVolume
  lmc down 10
control+XF86AudioLowerVolume
  lmc down 1
XF86AudioRaiseVolume
  lmc up 5
shift+XF86AudioRaiseVolume
  lmc up 10
control+XF86AudioRaiseVolume
  lmc up 1
XF86AudioNext
  lmc next
XF86AudioPlay
  lmc toggle
XF86AudioPrev
  lmc prev
XF86AudioStop
  lmc toggle
XF86MonBrightnessDown
  xbacklight -dec 15
XF86MonBrightnessUp
  xbacklight -inc 15


# Take screenshot
Print
  maim pic-full-$(date '+%y%m%d-%H%M-%S').png
# Pick screenshot type
shift + Print
  screenshot_select

# Increase volume
super + equal
  lmc up 5
# Decrease volume
super + minus
  lmc down 5

# Function keys
# F2 is restart in i3 right now.
# Change display
super + F3
  display_select
# Mount a USB drive or Android device
super + F9
  dmenu_mount
# Unmount a USB drive or Android device
super + F10
  dmenu_umount

    '';
  };
}
