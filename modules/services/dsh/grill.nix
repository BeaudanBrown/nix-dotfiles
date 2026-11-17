{ config, pkgs, ... }:
let
  cfg = config.services.dshTrial;
  port = toString cfg.port;
  nasIP = config.hostSpecs.nas.tailIP;
in
{
  services.dshTrial = {
    enable = true;
    gpu = true;
    hostname = "dsg.bepis.lol";
    listenAddress = config.hostSpec.tailIP;
  };

  # tailscale0 is trusted by the fleet firewall. A separate early drop chain
  # therefore enforces NAS-only access even on that otherwise trusted interface.
  systemd.services.dsh-agent = {
    wants = [ "tailscaled.service" ];
    after = [
      "tailscaled.service"
      "dsh-backend-guard.service"
    ];
    requires = [ "dsh-backend-guard.service" ];
  };
  systemd.services.dsh-backend-guard = {
    before = [ "dsh-agent.service" ];
    path = [ pkgs.nftables ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      nft list table inet dsh_backend >/dev/null 2>&1 || nft add table inet dsh_backend
      nft -f - <<'EOF'
      flush table inet dsh_backend
      add chain inet dsh_backend input { type filter hook input priority -10; policy accept; }
      add rule inet dsh_backend input tcp dport ${port} iifname != "tailscale0" drop
      add rule inet dsh_backend input meta nfproto ipv6 tcp dport ${port} drop
      add rule inet dsh_backend input tcp dport ${port} ip saddr != ${nasIP} drop
      EOF
    '';
  };
}
