{
  config,
  lib,
  ...
}:
{
  options.syncedState.root = lib.mkOption {
    type = lib.types.str;
    default = "${config.hostSpec.home}/.local/state/syncthing";
    description = ''
      Root directory for application state that is safe to synchronize between
      the primary fleet hosts. Applications should use native data-directory
      settings to store state beneath this path.
    '';
  };

  config.systemd.tmpfiles.rules = [
    "d ${config.syncedState.root} 0700 ${config.hostSpec.username} users - -"
  ];
}
