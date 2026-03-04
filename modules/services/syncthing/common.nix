{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  cfg = config.syncedState;
  user = config.hostSpec.username;
  home = config.hostSpec.home;
  syncRoot = "${home}/.local/state/syncthing";

  # Helper to get the parent directory of a path
  getParent = path: dirOf path;

in
{
  options = {
    syncedState = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            source = mkOption {
              type = types.str;
              description = "Path relative to HOME for the symlink (e.g. .config/watson/frames)";
            };
            target = mkOption {
              type = types.str;
              description = "Path relative to sync root (e.g. watson/frames)";
            };
            type = mkOption {
              type = types.enum [
                "file"
                "directory"
              ];
              default = "file";
              description = "Whether the target is a file or directory.";
            };
          };
        }
      );
      default = [ ];
      description = "List of files/folders to sync via the central Syncthing state folder.";
    };
  };

  config = lib.mkIf (cfg != [ ]) {
    systemd.tmpfiles.rules =
      let
        # 1. Calculate parent directories for Targets (in Syncthing folder)
        targetDirs = map (item: "${syncRoot}/${getParent item.target}") cfg;
        uniqueTargetDirs = targetDirs |> lib.filter (d: d != syncRoot) |> lib.unique;

        # 2. Calculate parent directories for Sources (in Home folder)
        sourceDirs = map (item: "${home}/${getParent item.source}") cfg;
        uniqueSourceDirs = sourceDirs |> lib.filter (d: d != home) |> lib.unique;

        # Helper to generate Directory rules
        mkDirRule = dir: "d ${dir} 0700 ${user} users - -";

        # Helper to generate existence rules for both ends of the mount
        # We need the target (backing file) and the source (mountpoint) to exist.
        mkExistenceRules =
          item:
          let
            targetPath = "${syncRoot}/${item.target}";
            sourcePath = "${home}/${item.source}";
          in
          if item.type == "directory" then
            [
              "d ${targetPath} 0700 ${user} users - -"
              "d ${sourcePath} 0700 ${user} users - -"
            ]
          else
            [
              "f ${targetPath} 0600 ${user} users - -"
              "f ${sourcePath} 0600 ${user} users - -"
            ];
      in
      (map mkDirRule uniqueTargetDirs)
      ++ (map mkDirRule uniqueSourceDirs)
      ++ (lib.concatMap mkExistenceRules cfg);

    systemd.mounts = map (item: {
      description = "Bind mount for synced state: ${item.source}";
      what = "${syncRoot}/${item.target}";
      where = "${home}/${item.source}";
      type = "none";
      options = "bind";
      wantedBy = [ "multi-user.target" ];
      before = [ "syncthing.service" ];
      after = [
        "systemd-tmpfiles-setup.service"
        "local-fs.target"
      ];
    }) cfg;
  };
}
