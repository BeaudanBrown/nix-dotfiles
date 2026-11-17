{
  config,
  inputs,
  pkgs,
  ...
}:
let
  tools = inputs.agent-tools-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    tools.secretspec
    pkgs.bitwarden-cli
  ];
  # No vault contents or unlock sessions are generated, copied or synchronized.
  # `bw config server` and login/unlock remain explicit normal-user operations.
  hm.primary.home.sessionVariables.SECRETSPEC_PROVIDER = "bw://?server=https://pw.bepis.lol";

  systemd.tmpfiles.rules = [
    # Mock values only; never place production credentials here.
    "d /var/lib/agent-mocks 2770 ${config.hostSpec.username} agent-workspace - -"
    "a /var/lib/agent-mocks - - - - u::rwx,g::rwx,m::rwx,o::---,d:u::rwx,d:g::rwx,d:m::rwx,d:o::---"
  ];
}
