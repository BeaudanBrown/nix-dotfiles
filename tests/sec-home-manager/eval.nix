# Fetch only named public pins; never load the fleet flake or its private inputs.
{ agent-workshop }:
let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  source = name: builtins.fetchTree lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
  nixpkgs = source "nixpkgs";
  home-manager = source "home-manager";
  lib = import (nixpkgs + "/lib");
  system = "x86_64-linux";
  tools = import (source "agent-tools-nixpkgs") { inherit system; };
  inputs = {
    inherit agent-workshop;
    agent-tools-nixpkgs.legacyPackages.${system} = tools;
    sops-nix.homeManagerModules.sops.options.sops.age.keyFile = lib.mkOption {
      type = lib.types.str;
    };
  };
  inherit (import ../../modules/host-spec/all-hosts.nix) hostSpecs;
  importLists = ../../generated/imports;
  importsFor = host: import (importLists + "/${host}.nix");
  secModule = ../../modules/cli/sec/main.nix;
  secretSpecModule = ../../modules/cli/secretspec/main.nix;
  mainHosts = builtins.filter (host: builtins.elem "main" hostSpecs.${host}.roots) (
    builtins.attrNames hostSpecs
  );
  secHosts = builtins.filter (host: builtins.elem secModule (importsFor host)) (
    builtins.attrNames hostSpecs
  );
  evaluate =
    host:
    import (nixpkgs + "/nixos/lib/eval-config.nix") {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        (home-manager + "/nixos")
        ../../modules/host-spec/minimal.nix
        {
          thisHost = "sec-fixture";
          hostSpecs.sec-fixture = {
            hostName = "sec-fixture";
            inherit (hostSpecs.${host}) roots;
            users = map (username: {
              inherit username;
              userFullName = username;
              email = "${username}@example.invalid";
            }) [ "operator" "secondary" ];
          };
          users.users = builtins.mapAttrs (username: _: {
            isNormalUser = true;
            home = "/home/${username}";
          }) {
            operator = { };
            secondary = { };
          };
          home-manager.sharedModules = [ { home.stateVersion = "26.05"; } ];
          system.stateVersion = "26.05";
        }
      ]
      ++ builtins.filter (module: builtins.elem module [ secModule secretSpecModule ]) (importsFor host);
    };
  main = evaluate "grill";
  nonMain = evaluate "agent";
  inherit (main) pkgs;
  inherit (main.config.home-manager.users) operator secondary;
  sec = operator.programs.sec;
  hasSec = packages: builtins.any (package: lib.getName package == "sec") packages;
in
assert secHosts == mainHosts;
assert sec.enable;
assert sec.vaultwardenUrl == "https://pw.bepis.lol";
assert sec.bwPackage.drvPath == pkgs.bitwarden-cli.drvPath;
assert sec.secretspecPackage.drvPath == tools.secretspec.drvPath;
assert operator.home.sessionVariables.SECRETSPEC_PROVIDER == "bw://?server=https://pw.bepis.lol";
assert !(secondary.programs ? sec);
assert hasSec operator.home.packages;
assert !(hasSec secondary.home.packages);
assert !(hasSec main.config.environment.systemPackages);
assert !(nonMain.config.home-manager.users.operator.programs ? sec);
assert !(hasSec nonMain.config.home-manager.users.operator.home.packages);
{
  inherit (sec) enable vaultwardenUrl;
  inherit secHosts;
  nonMainExcluded = true;
  bw = sec.bwPackage.version;
  secretspec = sec.secretspecPackage.version;
  primaryOnly = true;
}
