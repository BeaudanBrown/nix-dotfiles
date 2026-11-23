# Install sec for the primary user on hosts with the main root.
{
  inputs,
  pkgs,
  ...
}:
let
  tools = inputs.agent-tools-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # hmModules uses types.anything, which wraps bare module functions and hides
  # their named arguments. Pass the export through an imports list instead.
  hmModules.primary = [ { imports = [ inputs.agent-workshop.homeManagerModules.sec ]; } ];

  hm.primary.programs.sec = {
    enable = true;
    vaultwardenUrl = "https://pw.bepis.lol";
    bwPackage = pkgs.bitwarden-cli;
    secretspecPackage = tools.secretspec;
  };
}
