{ config, pkgs, ... }:
let
  domain = "meet.bepis.lol";
  port = 5280;
  wanMonitorScript = pkgs.writeShellApplication {
    name = "jvb-wan-monitor";
    runtimeInputs = with pkgs; [
      curl
      gnugrep
      systemd
      coreutils
    ];
    text = builtins.readFile ./jvb-wan-monitor.sh;
  };
in
{
  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8792"
  ];
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.jitsi-meet.hostName;
      upstreamPort = toString port;
      doNginx = false;
    }
  ];

  services.nginx.virtualHosts.${domain} = {
    enableACME = false;
    forceSSL = true;
    useACMEHost = domain;
  };

  services.jitsi-meet = {
    enable = true;
    # nginx.enable = false;
    hostName = domain;
    config = {
      enableWelcomePage = false;
      defaultLang = "en";
    };
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
    };
  };

  services.jitsi-videobridge = {
    enable = true;
    config.videobridge.ice.udp.port = 10000;
    extraProperties = {
      "org.jitsi.videobridge.SINGLE_PORT_HARVESTER_PORT" = "10000";
      "org.ice4j.ice.harvest.DISABLE_AWS_HARVESTER" = "true";
      "org.ice4j.ice.harvest.DISABLE_LINK_LOCAL_ADDRESSES" = "true";
      "org.ice4j.ipv6.DISABLED" = "true";
      "org.ice4j.ice.harvest.ALLOWED_INTERFACES" = "eno1";
      "org.ice4j.ice.harvest.BLOCKED_INTERFACES" = "^(lo|tailscale).*";
    };
  };

  networking.firewall.allowedUDPPorts = [ 10000 ];

  systemd.services.jitsi-videobridge2 = {
    wants = [
      "NetworkManager-wait-online.target"
      "prosody.service"
    ];
    after = [
      "NetworkManager-wait-online.target"
      "prosody.service"
    ];
  };

  # Periodically detect WAN IP changes and restart JVB automatically
  systemd.services.jvb-wan-monitor = {
    description = "Monitor WAN IP and restart Jitsi Videobridge on changes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${wanMonitorScript}/bin/jvb-wan-monitor";
    };
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  systemd.timers.jvb-wan-monitor = {
    description = "Periodic WAN IP check for Jitsi Videobridge";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      RandomizedDelaySec = "1m";
      Unit = "jvb-wan-monitor.service";
    };
  };

}
