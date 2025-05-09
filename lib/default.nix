{
  lib,
}:
with lib;
rec {
  relativeToRoot = lib.path.append ../.;

  importRecursiveCustom =
    { leaf, path }:
    let
      _scanPathsRec =
        _path:
        if (builtins.pathExists (_path + "/${leaf}")) then
          [ (_path + "/${leaf}") ]
        else
          builtins.readDir _path
          |> lib.attrsets.filterAttrs (_: type: type == "directory")
          |> lib.mapAttrsToList (name: _: _path + "/${name}")
          |> builtins.concatMap _scanPathsRec;
    in
    builtins.readDir path
    |> lib.attrsets.filterAttrs (_: type: type == "directory")
    |> lib.mapAttrsToList (name: _: path + "/${name}")
    |> builtins.concatMap _scanPathsRec;

  importHost =
    { host, path, ... }:
    importRecursiveCustom {
      inherit path;
      leaf = "${host}.nix";
    };

  importHome =
    path:
    importRecursiveCustom {
      inherit path;
      leaf = "home.nix";
    };

  importRecursive =
    path:
    importRecursiveCustom {
      inherit path;
      leaf = "default.nix";
    };

  importAll =
    {
      roots,
      host,
      spec,
    }:
    let
      importRoot =
        { spec, path, ... }@args:
        # Normal modules
        (importRecursive path)
        # Host specific modules
        ++ (importHost args)
        # Home manager modules
        ++ [
          {
            home-manager.users.${spec.username}.imports = importHome path;
            home-manager.extraSpecialArgs = {
              hostSpec = spec;
            };
          }
        ];
    in
    roots
    |> builtins.concatMap (
      module:
      let
        path = relativeToRoot "modules/${module}";
      in
      (importRoot {
        inherit path host spec;
      })
    );

  scanPaths =
    path:
    builtins.readDir path
    |> lib.attrsets.filterAttrs (
      child: _type:
      ((_type == "directory") && (builtins.pathExists (path + "/${child}/default.nix")))
      || ((lib.strings.hasSuffix ".nix" child) && (child != "default.nix"))
    )
    |> builtins.attrNames
    |> builtins.map (subPath: (path + "/${subPath}"));

  concatListsFromPaths =
    childAttrName: paths:
    builtins.concatLists (
      builtins.map (
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
      ) paths
    );

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

}
