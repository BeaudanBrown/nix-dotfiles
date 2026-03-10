{
  writeShellApplication,
  jq,
  nix,
}:
writeShellApplication {
  name = "generate-host-imports";
  runtimeInputs = [
    jq
    nix
  ];
  text = builtins.readFile ./generate-host-imports.sh;
}
