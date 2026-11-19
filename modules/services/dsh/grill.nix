{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dshTrial;
  port = toString cfg.port;
  nasIP = config.hostSpecs.nas.tailIP;
  signer = "dsh-git-signer";
  secret = "dsh/git-ssh-private-key";
  privateSocket = "/run/${signer}/agent.sock";
  clientDir = "/run/dsh-git-agent";
  clientSocket = "${clientDir}/agent.sock";
  secretUnits = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
  isolated = {
    User = signer;
    Group = signer;
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    LimitCORE = 0;
  };
in
{
  services.dshTrial = {
    enable = true;
    gpu = true;
    hostname = "dsg.bepis.lol";
    listenAddress = config.hostSpec.tailIP;
  };

  sops.secrets.${secret} = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
    owner = "root";
    restartUnits = [ "${signer}.service" ];
  };
  users.groups.${signer} = { };
  users.users.${signer} = {
    isSystemUser = true;
    group = signer;
  };

  # Only this unit receives the credential. Start with a fresh agent on rotation.
  systemd.services.${signer} = {
    after = secretUnits;
    requires = secretUnits;
    environment.SSH_AUTH_SOCK = privateSocket;
    serviceConfig = isolated // {
      RuntimeDirectory = signer;
      RuntimeDirectoryMode = "0700";
      LoadCredential = "identity:${config.sops.secrets.${secret}.path}";
      ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a ${privateSocket}";
      ExecStartPost = pkgs.writeShellScript "load-dsh-github-identity" ''
        set -eu
        for i in {1..100}; do
          test ! -S "$SSH_AUTH_SOCK" || break
          ${pkgs.coreutils}/bin/sleep 0.05
        done
        exec ${pkgs.openssh}/bin/ssh-add -q -H ${./github-known-hosts} -h git@github.com "$CREDENTIALS_DIRECTORY/identity"
      '';
    };
  };
  # OpenSSH checks the peer UID. Relay under the private signer's UID from a
  # systemd-owned listener; the development UID cannot read signer credentials.
  systemd.sockets.dsh-git-agent = {
    socketConfig = {
      ListenStream = clientSocket;
      SocketUser = "dsh-agent";
      SocketMode = "0600";
      RemoveOnStop = true;
    };
  };
  systemd.services.dsh-git-agent = {
    requires = [ "${signer}.service" ];
    after = [ "${signer}.service" ];
    serviceConfig = isolated // {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${privateSocket}";
    };
  };

  # tailscale0 is trusted by the fleet firewall. A separate early drop chain
  # therefore enforces NAS-only access even on that otherwise trusted interface.
  systemd.services.dsh-agent = {
    wants = [ "tailscaled.service" ];
    environment.SSH_AUTH_SOCK = clientSocket;
    serviceConfig.BindReadOnlyPaths = [
      "${clientDir}"
      "${./github-known-hosts}:/etc/ssh/ssh_known_hosts"
    ];
    after = [
      "tailscaled.service"
      "dsh-git-agent.socket"
      "dsh-backend-guard.service"
    ];
    requires = [
      "dsh-backend-guard.service"
      "dsh-git-agent.socket"
    ];
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
