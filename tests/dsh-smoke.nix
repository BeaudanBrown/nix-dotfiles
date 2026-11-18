# Disposable, account-free VM. No fleet secrets, NAS, GPU or OpenAI access.
let
  inputs = import ./dsh-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  state = "/var/lib/dsh-agent";
in
pkgs.testers.runNixOSTest {
  name = "dsh-web-service";
  nodes.machine = { config, lib, ... }: {
    imports = [ ../modules/services/dsh/main.nix ];
    _module.args.inputs = inputs;
    services.dshTrial.enable = true;
    users.groups.dsh-agent = { };
    users.users.dsh-agent = {
      isSystemUser = true;
      group = "dsh-agent";
    };
    systemd.tmpfiles.rules = [
      "d /agent 0770 dsh-agent dsh-agent - -"
      "d /var/lib/agent-mocks 0700 dsh-agent dsh-agent - -"
    ];
    # Inspect the actual launcher's composed config AFTER its first boot, as
    # the same user, inside the same root and mounts. No pre-seeding the profile.
    systemd.services.dsh-agent.serviceConfig.ExecReload =
      let
        sc = config.systemd.services.dsh-agent.serviceConfig;
        launcher = builtins.head (lib.splitString " --no-open" sc.ExecStart);
      in
      pkgs.writeShellScript "check-dsh-policy" ''
        set -eu
        test "$(pwd)" = "$HOME"
        test "$(readlink -f /etc/dsh-documents/deepseek-harness/default-workspace)" = /agent
        test -s "$DSH_HOME/profiles/web/package.json"
        test -w "$DSH_HOME/profiles/web/cordis.patch.yml"
        ${launcher} --dump-config > "$HOME/effective.yml"
        ${
          pkgs.python3.withPackages (p: [ p.pyyaml ])
        }/bin/python ${./dsh-check-policy.py} "$HOME/effective.yml"
      '';
    environment.systemPackages = [ pkgs.python3 ];
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("dsh-agent.service")
    machine.wait_for_open_port(3080, timeout=180)
    machine.wait_until_succeeds("python3 ${./dsh-check-ui.py}", timeout=120)
    machine.succeed("systemctl reload dsh-agent")
    machine.succeed("test -s ${state}/dsh/profiles/web/cordis.yml")
  '';
}
