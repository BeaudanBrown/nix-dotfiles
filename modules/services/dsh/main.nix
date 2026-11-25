{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.dshTrial;
  agentFontsConf = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  tools = inputs.agent-tools-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  dsh = inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.dsh;
  oauthPlugin = import ./codex-oauth.nix {
    inherit pkgs;
    dsh = cfg.package;
  };
  managedModules = pkgs.linkFarm "dsh-managed-node-modules" [
    {
      name = "dsh-native-codex-oauth";
      path = oauthPlugin;
    }
  ];
  gitHosts = [
    {
      host = "github.com";
      port = 22;
      user = "git";
      publicKeyFile = ./github-host-key.pub;
    }
    {
      host = "git.bepis.lol";
      port = 12595;
      user = "git";
      publicKeyFile = ./forgejo-host-key.pub;
    }
  ];
  knownHost =
    entry: if entry.port == 22 then entry.host else "[${entry.host}]:${toString entry.port}";
  sshConfigFile = "dsh-agent/ssh/ssh_config";
  sshKnownHostsFile = "dsh-agent/ssh/known_hosts";
  # Share the immutable NixOS-generated file between DSH and the signer.
  gitKnownHosts = config.environment.etc.${sshKnownHostsFile}.source;
  state = "/var/lib/dsh-agent";
  home = "${state}/home";
  dshHome = "${state}/dsh";
  runtimeDirectory = "dsh-agent";
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
      pkgs.gitMinimal
      pkgs.openssh
      pkgs.ripgrep
      pkgs.nix
    ];
  };
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
  # A read-only filesystem view, not another OS. No broad /home, /run or
  # /var/lib mount: private secrets, NFS mounts and privileged sockets stay out.
  root = pkgs.runCommand "dsh-service-root" { } ''
    mkdir -p "$out"/{agent,bin,usr/bin,etc/ssl/certs,etc/nix,nix/store,nix/var/nix/daemon-socket,proc,sys,dev/dri,tmp,var/tmp,opt/rocm,run/nix/daemon-socket,run/opengl-driver,run/opengl-driver-32,var/lib/dsh-agent,var/lib/agent-mocks}
    # rc.4 initializes the first Web workspace beneath documentsDirectory,
    # appending deepseek-harness/default-workspace and taking its realpath.
    mkdir -p "$out/etc/dsh-documents/deepseek-harness"
    ln -s /agent "$out/etc/dsh-documents/deepseek-harness/default-workspace"
    # Mount targets must exist: this tree itself lives in the read-only store.
    mkdir -p "$out/run/systemd/resolve" "$out/run/dsh-git-agent" "$out/run/${runtimeDirectory}" "$out/etc/ssh"
    mkdir -p "$out/run/user" "$out/etc/fonts"
    touch "$out/etc/fonts/fonts.conf"
    touch "$out"/etc/ssh/{ssh_config,ssh_known_hosts}
    ln -s /run/systemd/resolve/stub-resolv.conf "$out/etc/resolv.conf"
    touch "$out"/etc/{hosts,passwd,group,nsswitch.conf,gitconfig,dsh-host.patch.yml,dsh-policy.patch.yml}
    touch "$out/etc/nix/nix.conf" "$out/etc/ssl/certs/ca-certificates.crt"
    touch "$out/dev/kfd" "$out/dev/dri/renderD128" "$out/dev/dri/renderD129"
    ln -s ${pkgs.bashInteractive}/bin/bash "$out/bin/bash"
    ln -s ${pkgs.bashInteractive}/bin/sh "$out/bin/sh"
    ln -s ${pkgs.coreutils}/bin/env "$out/usr/bin/env"
  '';
  # Nix may deduplicate regular files by replacing their directory entries.
  # A file bind attached to the old entry in a private namespace then disappears
  # from path lookup. Never use the store template itself as the live mount tree.
  runtimeRoot = "/run/dsh-agent-roots/${builtins.baseNameOf (toString root)}";
  rootRules = pkgs.writeText "dsh-root.conf" ''
    d /run/dsh-agent-roots 0755 root root - -
    C ${runtimeRoot} 0555 root root - ${root}
  '';
  configFiles = {
    "${sshConfigFile}".text = ''
      Host ${lib.concatMapStringsSep " " (entry: entry.host) gitHosts}
        StrictHostKeyChecking yes
        BatchMode yes
        UserKnownHostsFile /dev/null
        GlobalKnownHostsFile /etc/ssh/ssh_known_hosts
        HostKeyAlgorithms ssh-ed25519
    '';
    "${sshKnownHostsFile}".text = lib.concatMapStrings (
      entry: "${knownHost entry} ${lib.removeSuffix "\n" (builtins.readFile entry.publicKeyFile)}\n"
    ) gitHosts;
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
    gitSshAddArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      default = [
        "-H"
        "${gitKnownHosts}"
      ]
      ++ lib.concatMap (entry: [
        "-h"
        "${entry.user}@${knownHost entry}"
      ]) gitHosts;
      description = "Pinned Git destination policy for the DSH signer.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.users.users ? dsh-agent && config.users.groups ? agent-workspace;
        message = "DSH needs the main-root shared workspace identity.";
      }
      {
        assertion = lib.all (entry: !(lib.elem entry config.nix.settings.trusted-users)) (
          [
            "dsh-agent"
            "*"
            "@dsh-agent"
            "@agent-workspace"
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
      "f ${state}/service.log 0600 dsh-agent dsh-agent - -"
    ];
    services.logrotate.settings.dsh-agent = {
      files = "${state}/service.log";
      frequency = "weekly";
      rotate = 4;
      missingok = true;
      notifempty = true;
      copytruncate = true; # systemd keeps the append fd open until restart
      su = "dsh-agent dsh-agent";
    };
    users.users.dsh-agent.extraGroups = lib.optional cfg.gpu "render";
    # Materialise before namespace setup, including on switch/rollback (not just
    # at boot). A changed template gets a new directory; never replace a live one.
    systemd.services.dsh-prepare-root = {
      description = "Prepare the root-owned DSH mount tree";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --create ${rootRules}";
        # Resolve the system account's allocated UID at activation, not evaluation.
        # Only the private root gets this alias; never bind the host login directory.
        ExecStartPost = pkgs.writeShellScript "dsh-user-runtime-alias" ''
          set -eu
          uid="$(${pkgs.coreutils}/bin/id -u dsh-agent)"
          ${pkgs.coreutils}/bin/ln -sfnT ../${runtimeDirectory} "${runtimeRoot}/run/user/$uid"
        '';
      };
    };
    systemd.services.dsh-agent = {
      description = "Private DSH development agent";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-tmpfiles-setup.service"
        "dsh-prepare-root.service"
        "systemd-resolved.service"
        "dsh-nfs-deny.service"
      ];
      requires = [
        "dsh-prepare-root.service"
        "dsh-nfs-deny.service"
        "systemd-resolved.service"
      ];
      environment = {
        HOME = home;
        XDG_RUNTIME_DIR = "/run/${runtimeDirectory}";
        # Web terminals use SHELL before falling back to the system user's nologin.
        SHELL = "/bin/bash";
        DSH_HOME = dshHome;
        DSH_BUNDLED_SKILL_DIR = "${inputs.agent-workshop.packages.${pkgs.stdenv.hostPlatform.system}.skills
        }";
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
        # DSH atomic writes can clear setgid on their staging directory. Make
        # the shared group the process default without changing the account.
        Group = "agent-workspace";
        UMask = "0007";
        RootDirectory = runtimeRoot;
        # systemd creates this directory and mounts it writable inside RootDirectory.
        RuntimeDirectory = runtimeDirectory;
        RuntimeDirectoryMode = "0700";
        MountAPIVFS = true;
        WorkingDirectory = home;
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
        # LibreOffice probes /proc/version; keep other users' processes hidden.
        ProcSubset = "all";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        # Build tools may preserve setgid on shared workspace directories.
        RestrictSUIDSGID = false;
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
          "${agentFontsConf}:/etc/fonts/fonts.conf"
          "${config.environment.etc.${sshConfigFile}.source}:/etc/ssh/ssh_config"
          "${gitKnownHosts}:/etc/ssh/ssh_known_hosts"
          "/nix/store"
          "/nix/var/nix/daemon-socket"
          # resolved replaces its stub file; bind the directory, not one inode.
          "/run/systemd/resolve"
          "/etc/hosts"
          "/etc/passwd"
          "/etc/group"
          "/etc/nsswitch.conf"
          "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt"
          # Node walks up from profiles/web. Leave the profile itself writable.
          "${managedModules}:${dshHome}/node_modules"
          "${./profile.patch.yml}:/etc/dsh-policy.patch.yml"
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
