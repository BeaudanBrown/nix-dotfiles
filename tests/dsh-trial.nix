# Evaluation-only fixture: never opens the fleet's private sopsSecrets input.
let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  source = name: builtins.fetchTree lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
  nixpkgs = source "nixpkgs";
  toolsSource = source "agent-tools-nixpkgs";
  baseLib = import (nixpkgs + "/lib");
  lib = baseLib.extend (
    _: _: {
      custom.sopsFileForModule = _: /dev/null;
      custom.mkBoolOpt =
        default: description:
        baseLib.mkOption {
          type = baseLib.types.bool;
          inherit default description;
        };
    }
  );
  tools = import toolsSource { system = "x86_64-linux"; };
  inputs.agent-tools-nixpkgs.legacyPackages.x86_64-linux = tools;
  evaluateWith =
    name: enabled: passthrough:
    (import (nixpkgs + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      specialArgs = { inherit inputs lib; };
      modules = [
        ../modules/services/agent-workspace/main.nix
        ../modules/cli/secretspec/main.nix
        ../modules/services/dsh/main.nix
        {
          imports =
            lib.optional enabled ../modules/services/dsh/grill.nix
            ++ lib.optionals (name == "nas") [
              ../modules/hosted-services/server.nix
              ../modules/services/dsh/nas.nix
              ../modules/services/docker-registry/nas.nix
            ];
        }
        ({ lib, ... }: {
          options.hostSpec = lib.mkOption { type = lib.types.attrs; };
          options.hostSpecs = lib.mkOption { type = lib.types.attrs; };
          options.custom.ports = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          options.hm = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          options.sops.secrets = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }: {
                  options = {
                    sopsFile = lib.mkOption { type = lib.types.path; };
                    mode = lib.mkOption {
                      type = lib.types.str;
                      default = "0400";
                    };
                    owner = lib.mkOption {
                      type = lib.types.str;
                      default = "root";
                    };
                    group = lib.mkOption {
                      type = lib.types.str;
                      default = "root";
                    };
                    path = lib.mkOption {
                      type = lib.types.str;
                      default = "/run/secrets/${name}";
                    };
                  };
                }
              )
            );
          };
          config = {
            hostSpec = {
              username = "operator";
              email = "test@example.invalid";
              tailIP = if name == "nas" then "100.64.0.1" else "100.64.0.2";
            };
            hostSpecs.grill.tailIP = "100.64.0.2";
            hostSpecs.nas.tailIP = "100.64.0.1";
            services.nginx.enable = name == "nas";
            services.nginx.recommendedProxySettings = true;
            custom.ports.assigned = {
              docker-registry = 5000;
              "nginx-ingress/public" = 10443;
              "nginx-ingress/tailnet" = 11443;
              "nginx-ingress/passthrough" = 12443;
            };
            networking.hostName = name;
            system.stateVersion = "26.05";
            users.users.operator.isNormalUser = true;
            services.syncthing = {
              enable = true;
              user = "operator";
              settings.devices = builtins.listToAttrs (
                map
                  (n: {
                    name = n;
                    value.id = "AAAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA";
                  })
                  [
                    "server"
                    "grill"
                    "laptop"
                    "t480"
                  ]
              );
            };
            fileSystems."/" = {
              device = "/dev/synthetic";
              fsType = "ext4";
            };
            boot.loader.grub.devices = [ "nodev" ];
            nix.settings.trusted-users = [
              "root"
              "@wheel"
            ];
            services.dshTrial = {
              enable = enabled;
              gpu = enabled;
            };
          };
        })
      ]
      ++ lib.optional passthrough {
        hostedServices = [
          {
            domain = "passthrough.example.invalid";
            upstreamHost = "100.64.0.3";
            upstreamPort = "443";
            tlsPassthrough = true;
            doACME = false;
          }
        ];
      };
    }).config;
  evaluate = name: enabled: evaluateWith name enabled false;
  nasPassthrough = evaluateWith "nas" false true;
  grill = evaluate "grill" true;
  nas = evaluate "nas" false;
  t480 = evaluate "t480" false;
  laptop = evaluate "laptop" false;
  sc = grill.systemd.services.dsh-agent.serviceConfig;
  folder = grill.services.syncthing.settings.folders.agent-workspace;
  passed =
    c:
    let
      failures = map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);
    in
    if failures == [ ] then true else throw (lib.concatStringsSep "\n" failures);
in
assert passed grill && passed nas && passed nasPassthrough && passed t480 && passed laptop;
# Even `false` triggers nix.conf validation errors without the experimental feature.
assert !(grill.nix.settings ? auto-allocate-uids);
assert !(nas.nix.settings ? auto-allocate-uids);
assert !(nas.systemd.services ? dsh-nfs-deny);
assert lib.all (
  listener: !listener.ssl || (listener.addr == "127.0.0.1" && listener.port == 11443)
) nasPassthrough.services.nginx.virtualHosts."dsg.bepis.lol".listen;
assert lib.hasInfix "real_ip_header proxy_protocol"
  nasPassthrough.services.nginx.virtualHosts."dsg.bepis.lol".extraConfig;
assert lib.all (c: !(c.systemd.services ? dsh-agent)) [
  nas
  t480
  laptop
];
assert
  nas.services.dockerRegistry.extraConfig.auth.htpasswd.path
  == "/run/credentials/docker-registry.service/htpasswd";
assert
  nas.systemd.services.docker-registry.serviceConfig.LoadCredential
  == [ "htpasswd:/run/secrets/docker-registry/htpasswd" ];
assert lib.hasInfix "bcrypt" nas.systemd.services.docker-registry.preStart;
assert lib.hasInfix "meta skgid $build_gid" grill.systemd.services.dsh-nfs-deny.script;
assert nas.services.nginx.virtualHosts."dsg.bepis.lol".listenAddresses == [ "100.64.0.1" ];
assert
  nas.services.nginx.virtualHosts."dsg.bepis.lol".locations."/".proxyPass == "http://100.64.0.2:3080";
assert nas.services.nginx.virtualHosts."dsg.bepis.lol".locations."/".proxyWebsockets;
assert !(nas.services.nginx.virtualHosts."dsg.bepis.lol".locations."/".recommendedProxySettings);
# Gixy rejects forwarding the raw, client-controlled $http_host value.
assert lib.hasInfix "proxy_set_header Host $host;"
  nas.services.nginx.virtualHosts."dsg.bepis.lol".locations."/".extraConfig;
assert
  !(lib.hasInfix "$http_host"
    nas.services.nginx.virtualHosts."dsg.bepis.lol".locations."/".extraConfig
  );
assert nas.security.acme.certs."dsg.bepis.lol".environmentFile == "/run/secrets/cloudflare/env";
assert nas.security.acme.defaults.dnsResolver == "1.1.1.1:53";
assert nas.security.acme.certs."registry.bepis.lol".dnsResolver == "1.1.1.1:53";
assert nas.security.acme.certs."dsg.bepis.lol".dnsResolver == "1.1.1.1:53";
assert nasPassthrough.security.acme.certs."dsg.bepis.lol".dnsResolver == "1.1.1.1:53";
assert !(lib.elem "dsg.bepis.lol" nas.services.cloudflare-dyndns.domains);
assert grill.sops.secrets == { } && !(grill.services.nginx.virtualHosts ? "dsg.bepis.lol");
assert lib.hasInfix "--host 100.64.0.2" sc.ExecStart;
assert lib.hasInfix "https://dsg.bepis.lol/" sc.ExecStart;
assert lib.hasInfix "ip saddr != 100.64.0.1 drop" grill.systemd.services.dsh-backend-guard.script;
assert lib.elem "dsh-backend-guard.service" grill.systemd.services.dsh-agent.requires;
# Launcher parsing stops at the first app flag: overlays must precede --no-open.
assert lib.hasInfix "--patch /etc/dsh-host.patch.yml --no-open" sc.ExecStart;
assert
  (lib.findFirst (s: s.domain == "dsg.bepis.lol") { tailnet = false; } nas.hostedServices).tailnet;
assert sc.User == "dsh-agent" && sc.NoNewPrivileges;
assert sc.MemoryHigh == "85%" && sc.MemoryMax == "90%" && sc.TasksMax == 4096;
assert sc.RestrictNamespaces && sc.PrivateDevices && sc.ProtectHome;
assert sc.CapabilityBoundingSet == "";
assert sc.RootDirectory != "";
assert lib.elem "/agent" sc.BindPaths;
assert !(lib.elem "/home" sc.BindPaths) && !(lib.elem "/run" sc.BindPaths);
assert lib.elem "/nix/var/nix/daemon-socket" sc.BindReadOnlyPaths;
assert lib.elem "-/dev/kfd" sc.BindPaths;
assert !(lib.elem "docker" grill.users.users.dsh-agent.extraGroups);
assert !(lib.elem "wheel" grill.users.users.dsh-agent.extraGroups);
assert lib.elem "agent-workspace" grill.users.users.operator.extraGroups;
assert folder.path == "/agent" && folder.ignorePerms;
assert lib.all
  (
    c:
    lib.elem "d /agent 2770 operator agent-workspace - -" c.systemd.tmpfiles.rules
    && lib.elem "agent-workspace" c.systemd.services.syncthing.serviceConfig.SupplementaryGroups
    && lib.elem "agent-workspace" c.systemd.services.syncthing-init.serviceConfig.SupplementaryGroups
    && c.systemd.services.syncthing.serviceConfig.PrivateUsers
  )
  [
    grill
    nas
    t480
    laptop
  ];
assert !(lib.elem "(?d)**/.git" folder.ignorePatterns);
assert !(lib.elem "(?d)**/*.sync-conflict-*" folder.ignorePatterns);
assert lib.elem "t480" folder.devices && lib.elem "server" folder.devices;
assert
  grill.hm.primary.home.sessionVariables.SECRETSPEC_PROVIDER == "bw://?server=https://pw.bepis.lol";
{
  status = "passed";
  package = grill.services.dshTrial.package.version;
  secretspec = tools.secretspec.version;
  # Evaluate derivations without realizing them; catches malformed unit/module
  # construction while deliberately excluding private fleet configuration.
  unit = grill.systemd.units."dsh-agent.service".unit;
  packageDrv = grill.services.dshTrial.package.drvPath;
  registryUnit = nas.systemd.units."docker-registry.service".unit;
  ingressUnit = nas.systemd.units."nginx.service".unit;
  passthroughIngressUnit = nasPassthrough.systemd.units."nginx.service".unit;
  backendGuardUnit = grill.systemd.units."dsh-backend-guard.service".unit;
  limitations = [
    "no build"
    "no host activation"
    "no browser/OAuth/GPU acceptance"
  ];
}
