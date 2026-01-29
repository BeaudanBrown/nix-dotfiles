{
  lib,
}:
with lib;
rec {
  relativeToRoot = lib.path.append ../.;

  # SOPS helpers
  # - Root-shared secret file: secrets/<root>.yaml
  # - Module-derived secret file: secrets/<basename-of-module>.yaml
  sopsRootFile = root: relativeToRoot "secrets/${root}.yaml";

  sopsFileForModule =
    moduleFile:
    let
      base = moduleFile |> builtins.baseNameOf |> removeSuffix ".nix";
    in
    relativeToRoot "secrets/${base}.yaml";

  importRecursive =
    { leaf, path }:
    let
      _scanPathsRec =
        _path:
        (if (builtins.pathExists (_path + "/${leaf}")) then [ (_path + "/${leaf}") ] else [ ])
        ++ (
          builtins.readDir _path
          |> lib.attrsets.filterAttrs (_: type: type == "directory")
          |> lib.mapAttrsToList (name: _: _path + "/${name}")
          |> builtins.concatMap _scanPathsRec
        );
    in
    builtins.readDir path
    |> lib.attrsets.filterAttrs (_: type: type == "directory")
    |> lib.mapAttrsToList (name: _: path + "/${name}")
    |> builtins.concatMap _scanPathsRec;

  importHost =
    { host, path }:
    importRecursive {
      inherit path;
      leaf = "${host}.nix";
    };

  importAll =
    {
      roots,
      host,
      extraSpecialArgs ? { },
      useHost ? true,
    }:
    let
      path = relativeToRoot "modules";
    in
    (if useHost then importHost { inherit host path; } else [ ])
    ++ (
      roots
      |> builtins.concatMap (
        category:
        # Normal modules
        (importRecursive {
          inherit path;
          leaf = "${category}.nix";
        })
        # Home manager configuration
        ++ [
          {
            home-manager = {
              inherit extraSpecialArgs;
              backupFileExtension = "backup";
            };
          }
        ]
      )
    );

  concatListsFromPaths =
    childAttrName: paths:
    paths
    |> builtins.map (
      path:
      let
        expr = import path;
      in
      if
        builtins.isAttrs expr
        && builtins.hasAttr childAttrName expr
        && builtins.typeOf (builtins.getAttr childAttrName expr) == "list"
      then
        builtins.getAttr childAttrName expr
      else
        [ ]
    )
    |> builtins.concatLists;

  ## Create a NixOS module option.
  ##
  ## ```nix
  ## lib.mkOpt nixpkgs.lib.types.str "My default" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt =
    type: default: description:
    mkOption { inherit type default description; };

  ## Create a NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkOpt' nixpkgs.lib.types.str "My default"
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt' = type: default: mkOpt type default null;

  ## Create a boolean NixOS module option.
  ##
  ## ```nix
  ## lib.mkBoolOpt true "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt = mkOpt types.bool;

  ## Create a boolean NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkBoolOpt true
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt' = mkOpt' types.bool;

  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  # ═══════════════════════════════════════════════════════════
  # Multi-User Secrets Helpers
  # ═══════════════════════════════════════════════════════════

  ## Create SOPS secrets for all users on a host.
  ## Usage in a module:
  ##   sops.secrets = lib.custom.sopsSecretForAllUsers config "ssh_key" {
  ##     sopsFile = ./secrets.yaml;
  ##     mode = "0600";
  ##   };
  ##
  ## This creates secrets named: "<username>_ssh_key" for each user
  sopsSecretForAllUsers =
    config: secretName: secretConfig:
    lib.listToAttrs (
      map (
        username:
        lib.nameValuePair "${username}_${secretName}" (
          secretConfig
          // {
            owner = username;
            inherit (config.users.users.${username}) group;
          }
        )
      ) config.hostSpec.usernames
    );

  ## Create SOPS secrets for specific users.
  ## Usage in a module:
  ##   sops.secrets = lib.custom.sopsSecretForUsers ["beau" "mikaerem"] "work_token" {
  ##     sopsFile = ./work-secrets.yaml;
  ##     mode = "0600";
  ##   };
  sopsSecretForUsers =
    usernames: secretName: secretConfig:
    lib.listToAttrs (
      map (
        username:
        lib.nameValuePair "${username}_${secretName}" (
          secretConfig
          // {
            owner = username;
          }
        )
      ) usernames
    );

  ## Create SOPS secrets for the primary user only.
  ## Usage in a module:
  ##   sops.secrets = lib.custom.sopsSecretForPrimaryUser config "api_key" {
  ##     sopsFile = ./secrets.yaml;
  ##     mode = "0600";
  ##   };
  sopsSecretForPrimaryUser = config: secretName: secretConfig: {
    "${config.hostSpec.primaryUser.username}_${secretName}" = secretConfig // {
      owner = config.hostSpec.primaryUser.username;
      inherit (config.users.users.${config.hostSpec.primaryUser.username}) group;
    };
  };

}
