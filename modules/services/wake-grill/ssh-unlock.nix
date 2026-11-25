{
  config,
  lib,
  pkgs,
  ...
}:
let
  publicKey = lib.removeSuffix "
" (builtins.readFile ./nas-unlock.pub);
  nasIP = config.hostSpecs.nas.tailIP;
  unlock = pkgs.writeShellScript "grill-ssh-unlock" ''
    exec ${pkgs.python3}/bin/python3 -I ${./unlock.py} ${lib.getExe pkgs.hyprlock}
  '';
in
{
  users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys = [
    ''restrict,from="${nasIP}",command="${unlock}" ${publicKey}''
  ];
}
