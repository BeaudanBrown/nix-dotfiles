{
  config,
  pkgs,
  ...
}:
let
  workspace = "${config.hostSpec.home}/documents/projects/todo-agent";
  initializer = pkgs.writeShellApplication {
    name = "vikunja-agent-init";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./agent/init-workspace.py} "$@"
    '';
  };
in
{
  environment.systemPackages = [
    initializer
    pkgs.nodejs_24
  ];

  # Stable import path lets project stubs use the new source on their next reload.
  # No global Pi extension: unrelated projects get no Vikunja tools.
  hm.primary.xdg.dataFile."vikunja-agent".source = ./agent;
  hm.primary.xdg.configFile."vikunja-agent/default.json".text = builtins.toJSON {
    baseUrl = "https://todo.bepis.lol";
    tokenFile = config.sops.secrets."vikunja/api-token".path;
  };
  hm.primary.home.file."documents/projects/todo-agent/AGENTS.md".source = ./agent/AGENTS.md;
  hmModules.primary = [
    ({ lib, ... }: {
      home.activation.vikunjaWorkspace = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        # Managed discovery requires a regular entrypoint, not a file symlink.
        # Preserve any profile/binding the operator has already selected.
        if [ ! -e ${lib.escapeShellArg "${workspace}/.pi/extensions/vikunja.ts"} ]; then
          run ${initializer}/bin/vikunja-agent-init ${lib.escapeShellArg workspace}
        fi
      '';
    })
  ];
}
