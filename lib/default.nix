{
  lib,
  inputs,
  snowfall-inputs,
}:

rec {
  relativeToRoot = lib.path.append ../.;
  # Create a list of all directories and nix files in a given folder excluding default.nix
  scanPaths =
    path:
    builtins.map (subPath: (path + "/${subPath}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
          (_type == "directory") # include directories
          || (
            # FIXME this barfs when child directories don't contain a default.nix
            # example:
            # error: getting status of '/nix/store/mx31x8530b758ap48vbg20qzcakrbc8 (see hosts/common/core/services/default.nix)a-source/hosts/common/core/services/default.nix': No such file or directory
            (path != "default.nix") # ignore default.nix
            && (lib.strings.hasSuffix ".nix" path) # include .nix files
          )
        ) (builtins.readDir path)
      )
    );

  concatListsFromPaths = childAttrName: paths: builtins.concatLists (
    builtins.map (path:
      let expr = import path;
      in if builtins.isAttrs expr &&
            builtins.hasAttr childAttrName expr &&
            builtins.typeOf (builtins.getAttr childAttrName expr) == "list"
         then builtins.getAttr childAttrName expr
         else []
    ) paths
  );
  ## Override a package's metadata
  ##
  ## ```nix
  ## let
  ##  new-meta = {
  ##    description = "My new description";
  ##  };
  ## in
  ##  lib.override-meta new-meta pkgs.hello
  ## ```
  ##
  #@ Attrs -> Package -> Package
  override-meta =
    meta: package:
    package.overrideAttrs (attrs: {
      meta = (attrs.meta or { }) // meta;
    });
  infuse = (import ./infuse.nix { inherit lib; }).v1.infuse;
  #infuse = (import (builtins.fetchGit {
  #      url = "https://codeberg.org/amjoseph/infuse.nix";
  #      name = "infuse.nix";
  #      ref = "refs/tags/v2.4";
  #      shallow = true;
  #      #publicKey = "F0B74D717CDE8412A3E0D4D5F29AC8080DA8E1E0";
  #    }) { inherit lib; }).v1.infuse;
}
