{ config, pkgs, ... }:
let
  project = "/var/lib/dump-site/project";
  publisher = import ./package.nix { inherit pkgs; };
  user = config.hostSpec.username;
  grillIP = config.hostSpecs.grill.tailIP;
in
{
  hostedServices = [
    {
      domain = "dump.bepis.lol";
      doNginx = false;
      manageNginxListeners = true;
    }
  ];

  services.nginx.virtualHosts."dump.bepis.lol" = {
    forceSSL = true;
    useACMEHost = "dump.bepis.lol";
    root = "/var/lib/dump-publisher/current";
    locations."/".tryFiles = "$uri $uri/ =404";
    locations."~ /\\.".extraConfig = "deny all;";
    extraConfig = ''
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy strict-origin-when-cross-origin always;
      add_header Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'none'" always;
    '';
  };

  environment.systemPackages = [ publisher ];

  # Chat-only capabilities. The ordinary Pi CLI and GRILL's writable export
  # remain unchanged. Commands are immutable host argv, not project scripts.
  services.pi-harness.bridgeChat.workspaceExecutor = {
    enable = true;
    projectDirectory = project;
    inherit user;
    commands = {
      check = [
        "${publisher}/bin/dump-publish"
        "check"
      ];
      publish = [
        "${publisher}/bin/dump-publish"
        "submit-local"
      ];
      status = [
        "${publisher}/bin/dump-publish"
        "status-local"
      ];
    };
    commandMounts = {
      requests = {
        source = "${project}/.publishing/requests";
        readOnly = false;
      };
      status = {
        source = "${project}/.publishing/status";
        readOnly = true;
      };
    };
  };
  services.pi-harness.bridgeChat.assistant = {
    files.enable = true;
    workspaceRoomIds = [ "!XljGtOqHxkwHiILSto:matrix.bepis.lol" ];
    projectCommands = {
      check = "Validate dump content and render a temporary Hugo site; does not publish.";
      publish = "Validate and publish the complete edit batch; returns a published receipt or pending/failure. No extra approval needed.";
      status = "Inspect recent publication receipts after a timeout; do not blindly publish again.";
    };
  };

  users.groups.dump-publisher = { };
  users.users.dump-publisher = {
    isSystemUser = true;
    group = "dump-publisher";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/dump-site 0755 root root - -"
    # The managed Matrix launcher requires the project root to be user-owned.
    # Keep publishing control directories separately owned below.
    "d ${project} 2775 ${user} users - -"
    "d ${project}/.publishing 0755 root root - -"
    "d ${project}/.publishing/requests 0755 ${user} users - -"
    "d ${project}/.publishing/status 0755 dump-publisher dump-publisher - -"
  ];
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    ${project} ${grillIP}(rw,sync,no_subtree_check,root_squash,fsid=104)
  '';
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2049 ];

  systemd.services.dump-publisher = {
    description = "Validate and atomically publish dump.bepis.lol snapshots";
    after = [ "systemd-tmpfiles-setup.service" ];
    unitConfig.RequiresMountsFor = project;
    serviceConfig = {
      Type = "oneshot";
      User = "dump-publisher";
      Group = "dump-publisher";
      UMask = "0022";
      StateDirectory = "dump-publisher";
      StateDirectoryMode = "0755";
      ExecStart = "${publisher}/bin/dump-publish consume --project ${project}";
      TimeoutStartSec = "15min";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      CapabilityBoundingSet = "";
      ReadWritePaths = [ "${project}/.publishing/status" ];
      InaccessiblePaths = [
        "-/run/secrets"
        "-/run/agenix"
      ];
      MemoryMax = "1G";
      TasksMax = 64;
    };
  };
  systemd.timers.dump-publisher = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitInactiveSec = "15s";
    };
  };
}
