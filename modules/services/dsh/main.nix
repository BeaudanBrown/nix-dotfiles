{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.dshTrial;
  tools = inputs.agent-tools-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  dsh = tools.deepseek-harness;
  state = "/var/lib/dsh-agent";
  home = "${state}/home";
  dshHome = "${state}/dsh";
  mockCli = pkgs.writeShellScriptBin "secretspec" ''
    exec ${pkgs.python3}/bin/python3 ${../../cli/secretspec/agent_provider.py} \
      ${tools.secretspec}/bin/secretspec "$@"
  '';
  runtime = pkgs.buildEnv {
    name = "dsh-agent-runtime";
    paths = [
      mockCli
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.git
      pkgs.curl
      pkgs.jq
      pkgs.ripgrep
      pkgs.nix
      pkgs.direnv
      pkgs.devenv
      pkgs.gnumake
      pkgs.openssh
      pkgs.python3
      pkgs.procps
    ];
  };
  profile = pkgs.runCommand "dsh-nix-profile" { } ''
    mkdir -p "$out/web"
    cat > "$out/web/package.json" <<'EOF'
    {"name":"dsh-profile-web","private":true,"dependencies":{},"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base","@deepseek-ai/dsh-web-app"]}}}
    EOF
    # User settings (including preview acknowledgement) are saved here by DSH.
    # Service policy is a separate, later Nix-owned CLI overlay.
    printf '[]\n' > "$out/web/cordis.patch.yml"
    cat > "$out/web/pnpm-workspace.yaml" <<'EOF'
    packages:
      - .
    nodeLinker: hoisted
    autoInstallPeers: false
    EOF
  '';
  connectionPatch = pkgs.writeText "dsh-host.patch.yml" (
    builtins.toJSON [
      {
        id = "connection";
        config = {
          trustedHosts = [ cfg.hostname ];
          cookieMaxAgeDays = 400;
        };
      }
    ]
  );
  emptyPatch = pkgs.writeText "dsh-empty.patch.yml" "[]\n";
  # A read-only filesystem view, not another OS. No broad /home, /run or
  # /var/lib mount: private secrets, NFS mounts and privileged sockets stay out.
  root = pkgs.runCommand "dsh-service-root" { } ''
    mkdir -p "$out"/{agent,bin,usr/bin,etc/ssl/certs,etc/nix,nix/store,nix/var/nix/daemon-socket,proc,sys,dev/dri,tmp,var/tmp,opt/rocm,run/nix/daemon-socket,run/opengl-driver,run/opengl-driver-32,var/lib/dsh-agent,var/lib/agent-mocks}
    # Mount targets must exist: this tree itself lives in the read-only store.
    touch "$out"/etc/{resolv.conf,hosts,passwd,group,nsswitch.conf,gitconfig,dsh-host.patch.yml,dsh-policy.patch.yml}
    touch "$out/etc/nix/nix.conf" "$out/etc/ssl/certs/ca-certificates.crt"
    touch "$out/dev/kfd" "$out/dev/dri/renderD128" "$out/dev/dri/renderD129"
    ln -s ${pkgs.bashInteractive}/bin/bash "$out/bin/bash"
    ln -s ${pkgs.bashInteractive}/bin/sh "$out/bin/sh"
    ln -s ${pkgs.coreutils}/bin/env "$out/usr/bin/env"
  '';
  configFiles = {
    "dsh-agent/gitconfig".text = ''
      [user]
        name = Development Agent
        email = agent@localhost
      [safe]
        directory = /agent/*
      [credential]
        helper =
    '';
    "dsh-agent/nix.conf".text = ''
      experimental-features = nix-command flakes pipe-operators
      accept-flake-config = false
    '';
  };
in
{
  options.services.dshTrial = {
    enable = lib.mkEnableOption "the dedicated-user DSH trial";
    package = lib.mkOption {
      type = lib.types.package;
      default = dsh;
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "dsh-${config.networking.hostName}.bepis.lol";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Concrete bind address; non-loopback listeners require an ingress guard.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3080;
    };
    gpu = lib.mkEnableOption "AMD compute devices (no display/input sockets)";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.users.users ? dsh-agent;
        message = "DSH needs the main-root shared workspace identity.";
      }
      {
        assertion = lib.all (entry: !(lib.elem entry config.nix.settings.trusted-users)) (
          [
            "dsh-agent"
            "*"
            "@dsh-agent"
          ]
          ++ map (g: "@${g}") config.users.users.dsh-agent.extraGroups
        );
        message = "DSH must be an untrusted Nix daemon client.";
      }
      {
        assertion =
          config.nix.settings.sandbox == true
          && !(config.nix.settings.sandbox-fallback or false)
          && config.nix.settings.build-users-group == "nixbld"
          && config.nix.nrBuildUsers > 0
          && !(config.nix.settings.auto-allocate-uids or false);
        message = "Agent Nix access requires sandboxing, the guarded nixbld group, no fallback and no dynamic build UIDs.";
      }
    ];
    nix.settings = {
      build-users-group = lib.mkDefault "nixbld";
      # Leave auto-allocate-uids unset: even false requires its experimental
      # feature. The assertion above rejects enabling it elsewhere.
    };
    environment.etc = configFiles;
    systemd.tmpfiles.rules = [
      "d ${state} 0700 dsh-agent dsh-agent - -"
      "d ${home} 0700 dsh-agent dsh-agent - -"
      "d ${dshHome} 0700 dsh-agent dsh-agent - -"
      # Also repairs ownership of mountpoint directories from the former
      # read-only profile setup; no sessions/authentication are removed.
      "d ${dshHome}/profiles 0700 dsh-agent dsh-agent - -"
      "d ${dshHome}/profiles/web 0700 dsh-agent dsh-agent - -"
    ];
    users.users.dsh-agent.extraGroups = lib.optional cfg.gpu "render";
    systemd.services.dsh-agent = {
      description = "Private DSH development agent";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-tmpfiles-setup.service"
        "dsh-nfs-deny.service"
      ];
      requires = [ "dsh-nfs-deny.service" ];
      environment = {
        HOME = home;
        DSH_HOME = dshHome;
        PATH = lib.mkForce "${runtime}/bin";
        DSH_PERMISSION_MODE = "danger-full-access";
        DSH_TELEMETRY_DISABLED = "1";
        DSH_TELEMETRY_MODE = "DISABLED";
        NIX_REMOTE = "daemon";
        NIX_CONF_DIR = "/etc/nix";
        GIT_CONFIG_NOSYSTEM = "1";
        GIT_CONFIG_GLOBAL = "/etc/gitconfig";
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      };
      serviceConfig = {
        Type = "simple";
        User = "dsh-agent";
        Group = "dsh-agent";
        UMask = "0007";
        RootDirectory = root;
        MountAPIVFS = true;
        WorkingDirectory = "/agent";
        ExecStartPre = "${pkgs.python3}/bin/python3 ${./seed-profile.py} ${profile}/web ${dshHome}/profiles/web";
        ExecStart = "${cfg.package}/bin/dsh --profile web --patch /etc/dsh-policy.patch.yml --patch /etc/dsh-host.patch.yml --no-open --host ${cfg.listenAddress} --port ${toString cfg.port} --public-url https://${cfg.hostname}/ --trusted-host ${cfg.hostname}";
        Restart = "on-failure";
        RestartSec = 5;
        KillMode = "control-group";
        TimeoutStopSec = 30;
        # Startup includes a bearer login URL. Keep all output private, not in
        # the shared journal. The operator reads it explicitly with sudo.
        StandardOutput = "append:${state}/service.log";
        StandardError = "append:${state}/service.log";
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        MemoryHigh = "85%";
        MemoryMax = "90%";
        TasksMax = 4096;
        CPUWeight = 50;
        IOWeight = 50;
        ReadWritePaths = [
          "/agent"
          state
          "/var/lib/agent-mocks"
        ];
        BindPaths = [
          "/agent"
          state
          "/var/lib/agent-mocks"
        ]
        ++ lib.optionals cfg.gpu [
          "-/dev/kfd"
          "-/dev/dri/renderD128"
          "-/dev/dri/renderD129"
        ];
        BindReadOnlyPaths = [
          "/nix/store"
          "/nix/var/nix/daemon-socket"
          "/etc/resolv.conf"
          "/etc/hosts"
          "/etc/passwd"
          "/etc/group"
          "/etc/nsswitch.conf"
          "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt"
          "${./profile.patch.yml}:/etc/dsh-policy.patch.yml"
          "${emptyPatch}:${dshHome}/cordis.patch.yml"
          "${connectionPatch}:/etc/dsh-host.patch.yml"
          "/etc/dsh-agent/gitconfig:/etc/gitconfig"
          "/etc/dsh-agent/nix.conf:/etc/nix/nix.conf"
        ]
        ++ lib.optionals cfg.gpu [
          "-/run/opengl-driver"
          "-/run/opengl-driver-32"
          "-/opt/rocm"
        ];
        DeviceAllow = lib.optionals cfg.gpu [
          "char-drm rw"
          "/dev/kfd rw"
        ];
      };
    };

    # Independent table: no firewall backend replacement. Fixed agent UID is
    # resolved at service start. Blocks NFS and RPC discovery on IPv4 and IPv6;
    # the root view also exposes no existing host NFS mounts.
    systemd.services.dsh-nfs-deny = {
      description = "Deny NFS/RPC egress for the DSH Unix identity";
      before = [ "dsh-agent.service" ];
      path = [
        pkgs.nftables
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        uid=$(id -u dsh-agent)
        build_gid=$(id -g nixbld1)
        # Never remove an existing guard before installing its replacement.
        nft list table inet dsh_agent >/dev/null 2>&1 || nft add table inet dsh_agent
        nft -f - <<EOF
        flush table inet dsh_agent
        add chain inet dsh_agent output { type filter hook output priority -10; policy accept; }
        add rule inet dsh_agent output meta skuid $uid tcp dport { 111, 2049, 20048 } reject
        add rule inet dsh_agent output meta skuid $uid udp dport { 111, 2049, 20048 } reject
        # Fixed-output derivations have network access under nixbld, not the
        # requesting UID. Guard those too (including non-DSH local builds).
        add rule inet dsh_agent output meta skgid $build_gid tcp dport { 111, 2049, 20048 } reject
        add rule inet dsh_agent output meta skgid $build_gid udp dport { 111, 2049, 20048 } reject
        EOF
      '';
    };
  };
}
