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
    services.resolved.enable = true;
    users.groups.dsh-agent = { };
    users.groups.agent-workspace = { };
    users.users.dsh-agent = {
      isSystemUser = true;
      group = "dsh-agent";
    };
    systemd.tmpfiles.rules = [
      "d /agent 2770 dsh-agent agent-workspace - -"
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
        test "$XDG_RUNTIME_DIR" = /run/dsh-agent
        test "$(stat -c %a:%u:%g "$XDG_RUNTIME_DIR")" = "700:$(id -u):$(id -g)"
        test -w "$XDG_RUNTIME_DIR"
        for skill in grilling grill-with-docs domain-modeling; do
          test -r "$DSH_BUNDLED_SKILL_DIR/$skill/SKILL.md"
        done
        # Exercise libc DNS inside the restricted unit, without Internet access.
        grep -Eq '^nameserver[[:space:]]+127\.0\.0\.53$' /etc/resolv.conf
        ${pkgs.glibc.bin}/bin/getent -s dns ahostsv4 _localdnsstub. | grep -q '^127\.0\.0\.53 '
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
    service = "dsh-agent.service"

    def main_pid():
        return int(machine.succeed(f"systemctl show --property=MainPID --value {service}"))

    def check_main_mounts(phase):
        pid = main_pid()
        assert pid > 0, f"{phase}: {service} has no main PID"
        # ExecReload can get a fresh namespace, masking missing mounts in MainPID.
        mountinfo = machine.succeed(f"awk '{{ print $5, $6 }}' /proc/{pid}/mountinfo")
        mounts = dict(line.split() for line in mountinfo.splitlines() if line.strip())
        for path in (
            "/etc/passwd",
            "/etc/group",
            "/etc/nsswitch.conf",
            "/etc/gitconfig",
            "/etc/ssl/certs/ca-certificates.crt",
            "/etc/ssh/ssh_config",
            "/etc/ssh/ssh_known_hosts",
        ):
            options = mounts.get(path, "")
            assert "ro" in options.split(","), (
                f"{phase}: MainPID {pid} lacks a read-only mount at {path} (options: {options!r})"
            )
            machine.succeed(
                f"test -s /proc/{pid}/root{path} || "
                f"{{ echo '{phase}: MainPID {pid} sees {path} missing or empty' >&2; exit 1; }}"
            )
        runtime_path = "/run/dsh-agent"
        assert "rw" in mounts.get(runtime_path, "").split(","), (
            f"{phase}: MainPID {pid} lacks a writable runtime directory mount"
        )
        assert machine.succeed(f"stat -Lc %a:%U:%G /proc/{pid}/root{runtime_path}").strip() == "700:dsh-agent:agent-workspace"
        # Keep the live bind targets off the store filesystem: store optimisation
        # must not be able to replace the mount targets beneath this process.
        configured_root = machine.succeed(
            f"systemctl show --property=RootDirectory --value {service}"
        ).strip()
        assert configured_root.startswith("/run/dsh-agent-roots/"), (
            f"{phase}: unexpected RootDirectory {configured_root!r}"
        )
        live_root, runtime_root, store_root = machine.succeed(
            f"stat -Lc %d:%i /proc/{pid}/root {configured_root} /nix/store"
        ).splitlines()
        assert live_root == runtime_root, f"{phase}: MainPID {pid} is not using {configured_root}"
        assert live_root.split(":", 1)[0] != store_root.split(":", 1)[0], (
            f"{phase}: MainPID {pid} root still shares the Nix store filesystem"
        )
        assert main_pid() == pid, f"{phase}: {service} changed PID during the mount check"
        return pid

    machine.start()
    machine.wait_for_unit(service)
    machine.wait_for_open_port(3080, timeout=180)
    boot_pid = check_main_mounts("boot")
    machine.wait_until_succeeds("python3 ${./dsh-check-ui.py}", timeout=120)
    machine.succeed(f"systemctl reload {service}")
    machine.succeed("test -s ${state}/dsh/profiles/web/cordis.yml")

    machine.succeed(f"systemctl restart {service}")
    machine.wait_for_unit(service)
    machine.wait_for_open_port(3080, timeout=180)
    restart_pid = check_main_mounts("restart")
    assert restart_pid != boot_pid, f"{service} kept MainPID {boot_pid} after restart"
  '';
}
