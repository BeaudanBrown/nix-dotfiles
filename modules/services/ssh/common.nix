{ config, lib, ... }:
{
  # TODO: SSH key population should NOT be minimal
  sops.secrets =
    (lib.mapAttrs (_: secret: secret // { sopsFile = lib.custom.sopsFileForModule __curPos.file; }) {
      "ssh/nas/pub" = { };
      "ssh/grill/pub" = { };
      "ssh/laptop/pub" = { };
      "ssh/t480/pub" = { };
      "ssh/pi4/pub" = { };
    })
    // (lib.mapAttrs (_: secret: secret // { sopsFile = lib.custom.sopsFileForModule __curPos.file; }) {
      "ssh/root/priv" = {
        path = "/root/.ssh/id_ed25519";
        mode = "0600";
        owner = "root";
        group = "root";
      };
      "ssh/root/pub" = {
        path = "/root/.ssh/id_ed25519.pub";
        mode = "0600";
        owner = "root";
        group = "root";
      };
    })
    // (lib.mapAttrs (_: secret: secret // { sopsFile = lib.custom.sopsFileForModule __curPos.file; }) {
      "ssh/${config.networking.hostName}/pub" = {
        path = "${config.hostSpec.home}/.ssh/id_ed25519.pub";
        mode = "0600";
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
      };
      "ssh/${config.networking.hostName}/priv" = {
        path = "${config.hostSpec.home}/.ssh/id_ed25519";
        mode = "0600";
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
      };
    });
}
