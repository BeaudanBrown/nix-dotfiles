{
  config,
  lib,
  pkgs,
  ...
}:
let
  primaryUser = config.hostSpec.username;

  oneplusWaydroid = pkgs.writeShellScriptBin "oneplus-waydroid" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "$uid" ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- "$0" "$@"
    fi

    runtime_dir="/run/user/$uid"
    wayland_socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null)"
    if [ -z "$wayland_socket" ]; then
      echo "No Wayland socket found under $runtime_dir" >&2
      exit 1
    fi

    export XDG_RUNTIME_DIR="$runtime_dir"
    export WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_socket")"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"

    exec ${config.virtualisation.waydroid.package}/bin/waydroid "$@"
  '';

  oneplusWaydroidFullUi = pkgs.writeShellScriptBin "oneplus-waydroid-full-ui" ''
    set -eu
    exec ${oneplusWaydroid}/bin/oneplus-waydroid show-full-ui
  '';

  oneplusWaydroidApp = pkgs.writeShellScriptBin "oneplus-waydroid-app" ''
    set -eu

    if [ "$#" -lt 1 ]; then
      echo "Usage: oneplus-waydroid-app ANDROID_PACKAGE [ARGS...]" >&2
      exit 64
    fi

    exec ${oneplusWaydroid}/bin/oneplus-waydroid app launch "$@"
  '';
in
{
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };

  environment.systemPackages = [
    config.virtualisation.waydroid.package
    pkgs.android-tools
    pkgs.waydroid-helper
    oneplusWaydroid
    oneplusWaydroidApp
    oneplusWaydroidFullUi
  ];

  hm.primary.xdg.desktopEntries = {
    waydroid-full-ui = {
      name = "Android";
      exec = "${oneplusWaydroidFullUi}/bin/oneplus-waydroid-full-ui";
      terminal = false;
      categories = [ "System" ];
    };
  };

  hm.primary.wayland.windowManager.hyprland.settings.windowrule = lib.mkAfter [
    {
      name = "waydroid-float";
      float = "on";
      "match:class" = "^(Waydroid)$";
    }
    {
      name = "waydroid-size";
      size = "100% 100%";
      "match:class" = "^(Waydroid)$";
    }
    {
      name = "waydroid-move";
      move = "0 0";
      "match:class" = "^(Waydroid)$";
    }
    {
      name = "waydroid-border";
      border_size = 0;
      "match:class" = "^(Waydroid)$";
    }
    {
      name = "waydroid-rounding";
      rounding = 0;
      "match:class" = "^(Waydroid)$";
    }
  ];
}
