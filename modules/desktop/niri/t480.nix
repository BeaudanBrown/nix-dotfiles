{
  config,
  lib,
  pkgs,
  ...
}:
let
  primaryUser = config.hostSpec.username;
  niriSessionCommand = "${config.programs.niri.package}/bin/niri-session";
  kdlString = builtins.toJSON;

  rofi_launch_dir = pkgs.writeShellApplication {
    name = "rofi_launch_dir";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fd
      pkgs.glib
    ];
    text = builtins.readFile ./scripts/rofi-launch-dir.sh;
  };

  niriIdle = pkgs.writeShellApplication {
    name = "niri-idle";
    runtimeInputs = [
      pkgs.hyprlock
      pkgs.procps
      pkgs.swayidle
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/niri-idle.sh;
  };

  launchers = [
    {
      key = "Return";
      app = "ghostty --title=main-terminal";
      workspace = "ghostty";
      title = "main-terminal";
    }
    {
      key = "S";
      app = "slack";
      workspace = "Slack";
      appId = "slack";
    }
    {
      key = "C";
      app = "signal-desktop";
      workspace = "Signal";
      appId = "signal";
    }
    {
      key = "W";
      app = "brave";
      workspace = "Brave";
      appId = "brave-browser";
    }
    {
      key = "M";
      app = "spotify";
      workspace = "Spotify";
      appId = "Spotify";
    }
    {
      key = "N";
      app = "caprine";
      workspace = "Caprine";
      title = "Caprine";
    }
    {
      key = "G";
      app = "steam";
      workspace = "Steam";
      appId = "Steam";
    }
    {
      key = "D";
      app = "discord";
      workspace = "Discord";
      appId = "discord";
    }
    {
      key = "Y";
      app = "ghostty --gtk-single-instance=false --title=nas -e ssh nas";
      workspace = "nas";
      title = "nas";
    }
    {
      key = "A";
      app = "ghostty --gtk-single-instance=false --title=agent -e ssh agent";
      workspace = "agent";
      title = "agent";
    }
    {
      key = "R";
      app = "ghostty --gtk-single-instance=false --title=rozzy -e ssh rozzy";
      workspace = "rozzy";
      title = "rozzy";
    }
    {
      key = "T";
      app = "ghostty --gtk-single-instance=false --title=bottom -e ssh bottom";
      workspace = "bottom";
      title = "bottom";
    }
    {
      key = "O";
      app = "ghostty --gtk-single-instance=false --title=grill -e ssh grill";
      workspace = "grill";
      title = "grill";
    }
    {
      key = "V";
      app = "windows-vm-start && windows-vm-viewer";
      workspace = "Windows";
      appId = "remote-viewer";
    }
  ];

  managedWorkspaceNames =
    (map (launcher: launcher.workspace) launchers)
    ++ [ "Teams" ]
    ++ [
      "1"
      "2"
      "3"
      "4"
      "5"
      "6"
      "7"
      "8"
      "9"
      "0"
    ];

  niriCompanion = pkgs.rustPlatform.buildRustPackage {
    pname = "niri-companion";
    version = "0.1.0";
    src = ./companion;
    cargoLock.lockFile = ./companion/Cargo.lock;
  };

  launcherBind =
    launcher:
    let
      matcherArgs =
        lib.optionals (launcher ? appId) [
          "--app-id-regex"
          ("^" + launcher.appId + "$")
        ]
        ++ lib.optionals (launcher ? title) [
          "--title-regex"
          launcher.title
        ];
      baseArgs = [
        "launch"
        "--workspace"
        launcher.workspace
        "--command"
        launcher.app
      ]
      ++ matcherArgs;
      command = "${niriCompanion}/bin/niri-companion ${lib.escapeShellArgs baseArgs}";
      pullCommand = "${niriCompanion}/bin/niri-companion ${
        lib.escapeShellArgs (baseArgs ++ [ "--pull" ])
      }";
      moveCommand = "${niriCompanion}/bin/niri-companion ${
        lib.escapeShellArgs [
          "move-focused"
          "--workspace"
          launcher.workspace
        ]
      }";
    in
    ''
      Mod+${launcher.key} { spawn-sh ${kdlString command}; }
      Mod+Alt+${launcher.key} { spawn-sh ${kdlString pullCommand}; }
      Mod+Shift+${launcher.key} { spawn-sh ${kdlString moveCommand}; }
    '';

  workspaceBind = workspace: ''
    Mod+${workspace.key} { spawn "${niriCompanion}/bin/niri-companion" "focus-workspace" "--workspace" "${workspace.key}"; }
    Mod+Shift+${workspace.key} { spawn "${niriCompanion}/bin/niri-companion" "move-focused" "--workspace" "${workspace.key}"; }
  '';

  stageWorkspaceRule =
    launcher:
    lib.optionalString ((launcher ? appId) || (launcher ? title)) ''
      window-rule {
          ${lib.optionalString (launcher ? appId)
            "match app-id=${kdlString ("^" + launcher.appId + "$")}"
          }
          ${lib.optionalString (launcher ? title) "match title=${kdlString launcher.title}"}
          open-on-workspace "__niri_stage"
          open-focused false
          default-column-width { proportion 1.0; }
          open-floating false
      }
    '';

  tilingAppIds = [
    "com.mitchellh.ghostty"
    "agent"
    "nas"
    "rozzy"
    "t480"
    "grill"
    "bottom"
    "signal"
    "brave-browser"
    "slack"
    "steam"
    "Steam"
    "discord"
    "teams-for-linux"
    "libreoffice.*"
    "VirtualBox Manager"
    "org.qbittorrent.qBittorrent"
    "net.lutris.Lutris"
    "@joplin/app-desktop"
    "Github Desktop"
    "com.obsproject.Studio"
    "vlc"
    "org.freecad.FreeCAD"
  ];
in
{
  # Keep all shared Hyprland modules intact, but make this host's active
  # compositor/session niri-only.
  programs.hyprland.enable = lib.mkForce false;
  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  environment.systemPackages = [
    niriCompanion
    pkgs.xwayland-satellite
  ];

  services = {
    displayManager.gdm.enable = lib.mkForce false;
    greetd = {
      enable = lib.mkForce true;
      settings = {
        initial_session = lib.mkForce {
          user = primaryUser;
          command = niriSessionCommand;
        };
        default_session = lib.mkForce {
          user = "greeter";
          command = "${pkgs.greetd}/bin/agreety --cmd ${lib.escapeShellArg niriSessionCommand}";
        };
      };
    };
  };

  hm.primary = {
    wayland.windowManager.hyprland.enable = lib.mkForce false;

    xdg.portal = {
      enable = true;
      config = lib.mkForce {
        common.default = [
          "gnome"
          "gtk"
        ];
        niri.default = [
          "gnome"
          "gtk"
        ];
      };
      extraPortals = lib.mkForce [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    programs.waybar = {
      settings.mainBar.modules-center = lib.mkForce [ "niri/workspaces" ];
      style = lib.mkForce ''
        .mainBar * {
          font-family: "JetBrainsMono Nerd Font Mono";
          font-size: 12pt;
        }

        .modules-right * {
          margin: 3;
        }

        #workspaces button#niri-workspace-__niri_stage {
          opacity: 0;
          min-width: 0;
          padding: 0;
          margin: 0;
          border: 0;
        }
      '';
    };

    services.hypridle.enable = lib.mkForce false;

    systemd.user.services = {
      niri-idle = {
        Unit = {
          Description = "Idle handling for the t480 niri session";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${niriIdle}/bin/niri-idle";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      niri-companion = {
        Unit = {
          Description = "t480 niri companion event daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Environment = [
            "NIRI_COMPANION_MANAGED_WORKSPACES_JSON=${builtins.toJSON managedWorkspaceNames}"
          ];
          ExecStart = "${niriCompanion}/bin/niri-companion daemon";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    home.file.".config/niri/config.kdl".text = ''
      input {
          keyboard {
              xkb {
                  layout "au"
                  options "caps:escape,fn:escape"
              }
              repeat-delay 175
              repeat-rate 50
          }

          touchpad {
              tap
              drag true
              natural-scroll
              accel-speed 0.2
              accel-profile "flat"
          }

          mouse {
              accel-speed 0.2
              accel-profile "flat"
          }

          trackpoint {
              accel-profile "flat"
          }

          focus-follows-mouse max-scroll-amount="0%"
          workspace-auto-back-and-forth
          mod-key "Super"
      }

      output "eDP-1" {
          scale 1
          position x=0 y=0
      }

      // Internal staging workspace used by niri-companion launch commands.
      // Waybar hides this workspace on t480.
      workspace "__niri_stage"

      layout {
          gaps 5
          center-focused-column "on-overflow"
          default-column-width { proportion 1.0; }
          preset-column-widths {
              proportion 0.33333
              proportion 0.5
              proportion 0.66667
              proportion 1.0
          }
          focus-ring {
              width 2
              active-color "#7fc8ff"
              inactive-color "#505050"
          }
          border {
              off
          }
      }

      prefer-no-csd
      screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

      environment {
          NIXOS_OZONE_WL "1"
          MOZ_ENABLE_WAYLAND "1"
          MOZ_WEBRENDER "1"
          XDG_SESSION_TYPE "wayland"
      }

      cursor {
          hide-when-typing
          hide-after-inactive-ms 2000
      }

      hotkey-overlay {
          skip-at-startup
      }

      xwayland-satellite {
          path "${pkgs.xwayland-satellite}/bin/xwayland-satellite"
      }

      spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet" "--indicator"
      spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      spawn-at-startup "${pkgs.waybar}/bin/waybar"

      window-rule {
          geometry-corner-radius 7
          clip-to-geometry true
      }

      window-rule {
          match is-active=false
          opacity 0.90
      }

      // Match the existing Hyprland model: float unknown windows, then tile the
      // known long-running app/workspace windows below.
      window-rule {
          match app-id=".*"
          open-floating true
      }

      ${lib.concatMapStrings stageWorkspaceRule launchers}

      ${lib.concatMapStrings (appId: ''
        window-rule {
            match app-id=${kdlString ("^" + appId + "$")}
            open-floating false
        }
      '') tilingAppIds}

      window-rule {
          match title="^Spotify"
          open-floating false
      }

      window-rule {
          match app-id="^VirtualBox Machine$"
          open-fullscreen true
          open-floating false
      }

      window-rule {
          match app-id="^remote-viewer$" title="^windows$"
          open-fullscreen true
          open-floating false
      }

      window-rule {
          match app-id="^(org.gnome.Nautilus|org.pulseaudio.pavucontrol|zoom)$"
          open-floating true
          default-column-width { proportion 0.6; }
          default-window-height { proportion 0.6; }
      }

      window-rule {
          match app-id="^nm-openconnect-auth-dialog$"
          open-floating true
          default-column-width { proportion 0.3; }
          default-window-height { proportion 0.6; }
      }

      window-rule {
          match app-id="^org.pwmt.zathura$"
          open-floating true
          default-column-width { proportion 0.4; }
          default-window-height { proportion 0.8; }
      }

      window-rule {
          match app-id="^Rofi$"
          open-floating true
      }

      binds {
          Mod+Space { spawn "${pkgs.rofi}/bin/rofi" "-show" "drun" "-matching" "fuzzy"; }
          Mod+P { spawn "${pkgs.rofi}/bin/rofi" "-show" "Browse " "-modes" "Browse :${rofi_launch_dir}/bin/rofi_launch_dir" "-matching" "fuzzy"; }
          Mod+I { spawn "${pkgs.rofi-rbw-wayland}/bin/rofi-rbw"; }

          Print { spawn-sh "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy"; }
          Shift+Print { screenshot; }

          Mod+Z { spawn "stt-dictate" "toggle"; }
          Mod+Shift+Z { spawn "stt-assist" "toggle"; }
          Mod+Alt+Z { spawn "thought-capture" "toggle"; }

          Mod+X { spawn "${pkgs.hyprlock}/bin/hyprlock"; }
          Mod+Shift+X { spawn "${pkgs.systemd}/bin/systemctl" "hibernate"; }
          Mod+Q repeat=false { close-window; }
          Mod+Shift+E { quit; }
          Mod+F { spawn "${niriCompanion}/bin/niri-companion" "toggle-workspace-width"; }
          Mod+Alt+F { spawn "${niriCompanion}/bin/niri-companion" "toggle-column-width"; }
          Mod+Shift+F { fullscreen-window; }
          Mod+Shift+Space { toggle-window-floating; }

          Mod+Tab { focus-workspace-previous; }
          Mod+Shift+Tab { focus-workspace-down; }

          Mod+Shift+Equal allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
          Mod+Shift+P allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "play-pause"; }
          Mod+Period allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "next"; }
          Mod+Comma allow-when-locked=true { spawn "${pkgs.playerctl}/bin/playerctl" "previous"; }
          Mod+Equal allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"; }
          Mod+Minus allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"; }
          Mod+B allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "+10%"; }
          Mod+Shift+B allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "10%-"; }

          Mod+H { focus-monitor-right; }
          Mod+Shift+H { move-window-to-monitor-right; }
          Mod+Alt+H { move-workspace-to-monitor-right; }

          Mod+J { spawn "${niriCompanion}/bin/niri-companion" "focus-column" "left"; }
          Mod+K { spawn "${niriCompanion}/bin/niri-companion" "focus-column" "right"; }
          Mod+L { focus-column-first; }
          Mod+Shift+J { spawn "${niriCompanion}/bin/niri-companion" "move-column" "left"; }
          Mod+Shift+K { spawn "${niriCompanion}/bin/niri-companion" "move-column" "right"; }
          Mod+Shift+L { move-column-to-first; }

          Mod+Ctrl+H { set-column-width "-20"; }
          Mod+Ctrl+L { set-column-width "+20"; }
          Mod+Ctrl+K { set-window-height "-20"; }
          Mod+Ctrl+J { set-window-height "+20"; }

          Mod+Ctrl+O { toggle-overview; }
          Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

      ${lib.concatMapStrings workspaceBind [
        {
          key = "1";
          index = 1;
        }
        {
          key = "2";
          index = 2;
        }
        {
          key = "3";
          index = 3;
        }
        {
          key = "4";
          index = 4;
        }
        {
          key = "5";
          index = 5;
        }
        {
          key = "6";
          index = 6;
        }
        {
          key = "7";
          index = 7;
        }
        {
          key = "8";
          index = 8;
        }
        {
          key = "9";
          index = 9;
        }
        {
          key = "0";
          index = 10;
        }
      ]}
      ${lib.concatMapStrings launcherBind launchers}
      }
    '';
  };
}
