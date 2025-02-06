{ options
, config
, pkgs
, lib
, inputs
, namespace
, ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.nix;

  substituters-submodule = types.submodule (
    { name, ... }:
    {
      options = with types; {
        key = mkOpt (nullOr str) null "The trusted public key for this substituter.";
      };
    }
  );
in
{
  options.${namespace}.nix = with types; {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt package pkgs.lix "Which nix package to use.";

    default-substituter = {
      url = mkOpt str "https://cache.nixos.org" "The url for the substituter.";
      key =
        mkOpt str "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "The trusted public key for the substituter.";
    };

    extra-substituters = mkOpt (attrsOf substituters-submodule) { } "Extra substituters to configure.";
  };

  config = mkIf cfg.enable {
    assertions = mapAttrsToList
      (name: value: {
        assertion = value.key != null;
        message = "dotfiles.nix.extra-substituters.${name}.key must be set";
      })
      cfg.extra-substituters;

    nix = {
      package = cfg.package;

      gc = {
        automatic = true;
        dates = "weekly";
        options = "-d";
      };

      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        trusted-users = [ "root" "@wheel" ];

        substituters = [
          cfg.default-substituter.url
        ] ++ (mapAttrsToList (name: value: name) cfg.extra-substituters);
        trusted-public-keys = [
          cfg.default-substituter.key
        ] ++ (mapAttrsToList (name: value: value.key) cfg.extra-substituters);
      };
    };
  };
}
