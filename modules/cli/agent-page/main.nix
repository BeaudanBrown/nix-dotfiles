# Install agent-page for the primary user on hosts with the main root.
{
  inputs,
  pkgs,
  ...
}:
let
  settings = import ./settings.nix;
in
{
  hm.primary.home.packages = [
    inputs.agent-workshop.packages.${pkgs.stdenv.hostPlatform.system}.agent-page
  ];
  hm.primary.home.sessionVariables = {
    AGENT_PAGE_OUT_DIR = settings.outDir;
    AGENT_PAGE_MAX_BYTES = toString settings.maxBytes;
  };
}
