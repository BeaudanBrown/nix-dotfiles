{
  config,
  lib,
  pkgs,
  ...
}:
let
  controller =
    (pkgs.haskellPackages.callPackage ./stream-session/package.nix { }).overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
        postInstall = (old.postInstall or "") + ''
          wrapProgram "$out/bin/stream-session" --prefix PATH : ${
            lib.makeBinPath [
              config.programs.hyprland.package
              pkgs.systemd
              pkgs.steam
              (import ../../desktop/hyprland/scripts/hyprland_show_app.nix { inherit pkgs; })
            ]
          }
        '';
      });
  command = lib.getExe controller;
  nasIP = config.hostSpecs.nas.tailIP;
  app =
    name: steam:
    {
      inherit name;
      image-path = if steam then "steam.png" else "desktop.png";
      prep-cmd = [
        {
          do = "${command} prepare${lib.optionalString steam " --steam"}";
          undo = "${command} stop";
        }
      ];
    }
    // lib.optionalAttrs steam { detached = [ "${command} launch" ]; };
in
{
  environment.systemPackages = [ controller ];

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = false; # wlr capture does not require KMS privileges.
    openFirewall = true;
    settings = {
      sunshine_name = "grill";
      capture = "wlr";
      encoder = "vaapi";
      gamepad = "generic";
      key_rightalt_to_key_win = "enabled";
      output_name = "STREAM";
      upnp = "disabled";
      hevc_mode = 2; # SDR HEVC Main; HDR is not configured for this output.
      av1_mode = 1; # Do not advertise AV1: RX 6900 XT has no AV1 encoder.
      max_bitrate = 0;
      stream_audio = "enabled";
      # The proxy's 100.64/10 source may be classified as WAN. Access to the
      # management port is instead restricted by the early firewall guard below.
      origin_web_ui_allowed = "wan";
    };
    applications.apps = [
      (app "Streaming Desktop" false)
      (app "Steam Big Picture" true)
    ];
  };

  systemd.user.services.stream-session = {
    description = "Moonlight virtual output and session controller";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionUser = config.hostSpec.username;
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${command} daemon";
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStartSec = 60;
      TimeoutStopSec = 5;
      UMask = "0077";
    };
  };
  systemd.user.services.sunshine = {
    requires = [ "stream-session.service" ];
    after = [ "stream-session.service" ];
    unitConfig.ConditionUser = config.hostSpec.username;
  };

  # tailscale0 is otherwise trusted fleet-wide. Guard management traffic before
  # those ACCEPT rules, and permit NAS only when it actually arrives over Tailscale.
  networking.firewall = lib.mkIf (!config.networking.nftables.enable) {
    extraCommands = ''
      ip46tables -t raw -N sunshine-ui 2>/dev/null || true
      ip46tables -t raw -F sunshine-ui
      ip46tables -t raw -A sunshine-ui -i lo -j RETURN
      iptables -t raw -A sunshine-ui -i tailscale0 -s ${nasIP} -j RETURN
      ip46tables -t raw -A sunshine-ui -j DROP
      ip46tables -t raw -D PREROUTING -p tcp --dport 47990 -m addrtype --dst-type LOCAL -j sunshine-ui 2>/dev/null || true
      ip46tables -t raw -I PREROUTING 1 -p tcp --dport 47990 -m addrtype --dst-type LOCAL -j sunshine-ui
    '';
    extraStopCommands = ''
      ip46tables -t raw -D PREROUTING -p tcp --dport 47990 -m addrtype --dst-type LOCAL -j sunshine-ui 2>/dev/null || true
      ip46tables -t raw -F sunshine-ui 2>/dev/null || true
      ip46tables -t raw -X sunshine-ui 2>/dev/null || true
    '';
  };
  networking.nftables.tables.sunshine-ui = lib.mkIf config.networking.nftables.enable {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority -10; policy accept;
        iifname "lo" tcp dport 47990 accept
        iifname "tailscale0" ip saddr ${nasIP} tcp dport 47990 accept
        tcp dport 47990 drop
      }
    '';
  };
}
