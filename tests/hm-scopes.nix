# Evaluation-only regression for the production host-spec bridge. No fleet secrets.
let
  inputs = import ./dsh-inputs.nix;
  evaluated = import (inputs.nixpkgs + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    specialArgs.inputs.sops-nix.homeManagerModules.sops = { lib, ... }: {
      options.sops.age.keyFile = lib.mkOption { type = lib.types.str; };
    };
    modules = [
      (inputs.home-manager + "/nixos")
      ../modules/host-spec/minimal.nix
      ({ lib, ... }: {
        thisHost = "test";
        hostSpecs.test = {
          hostName = "test";
          roots = [ ];
          users = map (username: {
            inherit username;
            email = "${username}@example.invalid";
            userFullName = username;
          }) [ "operator" "second" ];
        };
        users.users = lib.genAttrs [ "operator" "second" ] (_: { isNormalUser = true; });
        system.stateVersion = "26.05";
        hm.all.home.stateVersion = "26.05";
        hm.all.imports = [ ({ config, ... }: { home.sessionVariables.SCOPE_HOME = config.home.homeDirectory; }) ];
        hm.primary.programs.direnv.config.whitelist.prefix = [ "/base/" ];
        hm.operator.home.sessionVariables.NAMED_PRIMARY = "yes";
        hm.second.home.sessionVariables.SECOND_ONLY = "yes";
      })
      ({ lib, ... }: { hm.primary.programs.direnv.config.whitelist.prefix = lib.mkAfter [ "/agent/" ]; })
    ];
  };
  inherit (evaluated.config.home-manager.users) operator second;
in
assert operator.home.sessionVariables.SCOPE_HOME == "/home/operator";
assert second.home.sessionVariables.SCOPE_HOME == "/home/second";
assert operator.home.sessionVariables.NAMED_PRIMARY == "yes";
assert second.home.sessionVariables.SECOND_ONLY == "yes";
assert !(operator.home.sessionVariables ? SECOND_ONLY || second.home.sessionVariables ? NAMED_PRIMARY);
assert operator.programs.direnv.config.whitelist.prefix == [ "/base/" "/agent/" ];
assert !(second.programs.direnv.config ? whitelist);
true
