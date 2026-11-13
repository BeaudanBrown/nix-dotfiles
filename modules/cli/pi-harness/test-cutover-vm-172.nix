# Synthetic VM only. Supply the pinned nixpkgs, generated fixture and bridge outputs.
{
  nixpkgs,
  fixturePath,
  bridgePath,
  system ? "x86_64-linux",
}:
let
  pkgs = import nixpkgs { inherit system; };
  fixture = builtins.storePath fixturePath;
  bridge = builtins.storePath bridgePath;
  adapter = ./cutover-172.nix;
  prepare = pkgs.writeText "prepare-synthetic-cutover.py" ''
    import hashlib, json, os, shutil
    from pathlib import Path
    base = Path('/home/beau/.local/state/pi-managed-sessions')
    pairs = [("state", base / "relay"), ("manifests", base / "manifests"),
             ("native", base / "project-sessions"), ("account", Path('/var/lib/private/pi-chat-transport'))]
    for name, destination in pairs:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(Path('${fixture}') / name, destination)
        for file in destination.rglob('*'):
            if file.is_file():
                data = file.read_bytes()
                if b'"fixture"' in data:
                    file.chmod(0o600)
                    file.write_bytes(data.replace(b'"fixture"', b'"nas"'))
        for file in [destination, *destination.rglob('*')]:
            os.chown(file, 65534 if name == 'account' else 1000, 65534 if name == 'account' else 100)
            file.chmod(0o700 if file.is_dir() else 0o600)
    for directory in [base / 'coordinator', Path('/home/beau/.pi/agent/sessions'),
                      Path('/var/lib/pi-chat-model'), Path('/var/lib/pi-chat-files')]:
        directory.mkdir(parents=True, exist_ok=True)
        os.chown(directory, 1000, 100)
        directory.chmod(0o700)
    for directory in [Path('/home/beau/.local'), Path('/home/beau/.local/state'), base,
                      Path('/home/beau/.pi'), Path('/home/beau/.pi/agent')]:
        os.chown(directory, 1000, 100)
        directory.chmod(0o700)
    for name in ['requests.sqlite-journal', 'managed-account.sqlite-journal']:
        path = Path('/var/lib/private/pi-chat-transport') / name
        path.write_bytes(b'opaque synthetic hot journal: never recovered')
        os.chown(path, 65534, 65534)
        path.chmod(0o600)
    roots = [destination for _, destination in pairs] + [base / 'coordinator', Path('/home/beau/.pi/agent/sessions'), Path('/var/lib/pi-chat-model'), Path('/var/lib/pi-chat-files')]
    inventory = {str(file): hashlib.sha256(file.read_bytes()).hexdigest() for root in roots for file in root.rglob('*') if file.is_file()}
    Path('/tmp/original-hashes.json').write_text(json.dumps(inventory))
  '';
  fakeSyncApi = pkgs.writeText "synthetic-syncthing-api.py" ''
    import subprocess
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from pathlib import Path
    from xml.etree import ElementTree
    directory = Path('/tmp/fake-sync')
    directory.mkdir(mode=0o700, exist_ok=True)
    config = directory / 'config.xml'
    if not config.exists():
        subprocess.run(['${pkgs.syncthing}/bin/syncthing', 'generate', '--home='+str(directory)],
                       check=True, stdout=subprocess.DEVNULL, env={'HOME': '/home/beau', 'PATH': '/nonexistent'})
    document = ElementTree.parse(config)
    gui = document.getroot().find('gui')
    gui.set('enabled', 'true')
    gui.set('tls', 'false')
    gui.find('address').text = '127.0.0.1:8384'
    gui.find('apikey').text = 'synthetic-cutover-test-only'
    document.write(config, encoding='utf-8')
    body = Path('${./test-cutover-syncthing-172.json}').read_bytes()
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            with Path('/tmp/fake-sync-requests').open('a') as stream:
                stream.write(self.command+' '+self.path+'\n')
            if self.path != '/rest/system/config' or self.headers.get('X-API-Key') != 'synthetic-cutover-test-only':
                self.send_error(403)
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def do_POST(self):
            with Path('/tmp/fake-sync-requests').open('a') as stream:
                stream.write('FORBIDDEN POST\n')
            self.send_error(405)
        def log_message(self, *_args):
            pass
    with HTTPServer(('127.0.0.1', 8384), Handler) as server:
        server.serve_forever()
  '';
in
pkgs.testers.runNixOSTest {
  name = "pi-native-cutover-172-root-owner";
  globalTimeout = 900;
  nodes.machine =
    {
      lib,
      pkgs,
      ...
    }:
    {
      disabledModules = [ "services/networking/syncthing.nix" ];
      imports = [
        (
          {
            config,
            lib,
            pkgs,
            ...
          }:
          import adapter {
            inherit config pkgs;
            lib = lib.extend (
              _: previous: {
                custom.mkBoolOpt =
                  default: description:
                  previous.mkOption {
                    inherit default description;
                    type = previous.types.bool;
                  };
              }
            );
          }
        )
      ];
      options = {
        hostSpec = lib.mkOption { type = lib.types.attrs; };
        services.pi-harness.matrixBridge = lib.mkOption { type = lib.types.attrs; };
        services.syncthing = {
          enable = lib.mkOption { type = lib.types.bool; };
          package = lib.mkOption { type = lib.types.package; };
          configDir = lib.mkOption { type = lib.types.str; };
          settings.folders = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options.paused = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              }
            );
          };
        };
      };
      config = {
        networking.hostName = "nas";
        hostSpec = {
          username = "beau";
          home = "/home/beau";
        };
        users.users.beau = {
          isNormalUser = true;
          uid = 1000;
          group = "users";
          linger = true;
        };
        services.pi-harness.matrixBridge = {
          enable = true;
          user = "beau";
          hostId = "nas";
          package = bridge;
          botUserId = "@bot:example.org";
          operatorUserId = "@operator:example.org";
          roots = [ ];
          stateDirectory = "%h/.local/state/pi-matrix-bridge";
        };
        services.syncthing = {
          enable = true;
          package = pkgs.syncthing;
          configDir = "/tmp/fake-sync";
          settings.folders.state-sync.paused = true;
        };
        services.piNativeCutover172.enable = true;
        specialisation.start.configuration.services.piNativeCutover172.startAfterMigration = true;
        systemd.services.syncthing.serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${fakeSyncApi}";
          User = "beau";
          UMask = "0077";
        };
        systemd.services.pi-chat-transport.serviceConfig = {
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          DynamicUser = true;
          StateDirectory = "pi-chat-transport";
          StateDirectoryMode = "0700";
          ProtectHome = true;
        };
        systemd.services.pi-chat-model.serviceConfig = {
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          User = "beau";
          ProtectHome = true;
        };
        systemd.user.services.pi-matrix-bridge.serviceConfig.ExecStart =
          "${pkgs.coreutils}/bin/sleep infinity";
        environment.systemPackages = [
          pkgs.python3
          pkgs.sqlite
          pkgs.util-linux
        ];
        virtualisation.memorySize = 2048;
        virtualisation.cores = 2;
        system.stateVersion = "26.05";
      };
    };
  testScript = ''
    machine.start()
    machine.wait_for_unit('multi-user.target')
    machine.wait_for_unit('user@1000.service')
    machine.wait_for_open_port(8384)
    machine.succeed('${pkgs.python3}/bin/python3 ${prepare}')
    machine.succeed('systemctl start pi-chat-transport.service pi-chat-model.service')
    machine.succeed('test "$(stat -c %u /var/lib/private/pi-chat-transport)" = 65534')
    machine.succeed('test ! -e /var/lib/pi-chat-transport')
    machine.fail('pi-native-cutover-172 gate')
    # A real, already-loaded fixture consumer, then remove its source before
    # the job establishes effective masks. No live host or real relay involved.
    uctl = 'runuser -u beau -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user '
    machine.succeed("install -d -o beau -g users /home/beau/.config/systemd/user")
    machine.succeed("printf '[Service]\\nExecStart=${pkgs.coreutils}/bin/sleep infinity\\n' > /home/beau/.config/systemd/user/pi-managed-session-relay.service")
    machine.succeed(uctl + 'daemon-reload')
    machine.succeed(uctl + 'start pi-managed-session-relay.service')
    old_pid = machine.succeed(uctl + 'show pi-managed-session-relay.service -p MainPID --value').strip()
    machine.succeed('rm /home/beau/.config/systemd/user/pi-managed-session-relay.service')
    machine.succeed('umask 077; pi-native-cutover-172 permit-text > /run/pi-native-cutover-172-approved')
    status, output = machine.execute('systemctl restart pi-native-cutover-172.service')
    if status:
        print(machine.succeed('journalctl -u pi-native-cutover-172.service --no-pager'))
        raise Exception(output)
    machine.succeed('test -f /var/lib/pi-native-cutover-172/complete.json')
    machine.succeed("python3 -c 'from pathlib import Path; assert Path(\"/tmp/fake-sync-requests\").read_text().splitlines() == [\"GET /rest/system/config\"]'")
    machine.succeed('test ! -e /proc/' + old_pid)
    machine.succeed('test "$(' + uctl + 'show pi-managed-session-relay.service -p LoadState --value)" = masked')
    machine.succeed('runuser -u beau -g pi-native-cutover-172 -- test -r /var/lib/pi-native-cutover-172/source/source.json')
    machine.fail('runuser -u beau -g pi-native-cutover-172 -- chmod 0600 /var/lib/pi-native-cutover-172/source/source.json')
    machine.fail("runuser -u beau -g pi-native-cutover-172 -- sh -c 'echo changed >> /var/lib/pi-native-cutover-172/bundle/source.json'")
    machine.succeed('test "$(stat -c %u:%a /var/lib/pi-native-cutover-172/source/source.json)" = 0:440')
    machine.succeed('test "$(stat -c %u /home/beau/.local/state/pi-matrix-bridge/bridge.sqlite)" = 1000')
    machine.succeed('test "$(stat -c %u /var/lib/private/pi-chat-transport)" = 65534')
    machine.succeed("python3 -c 'import hashlib,json; from pathlib import Path; data=json.loads(Path(\"/tmp/original-hashes.json\").read_text()); assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in data.items())'")
    machine.fail('systemctl is-active pi-chat-transport.service')
    machine.fail(uctl + 'is-active pi-matrix-bridge.service')
    # Completion survives later work, unavailable snapshots and a fresh boot.
    machine.succeed("runuser -u beau -- sqlite3 /home/beau/.local/state/pi-matrix-bridge/bridge.sqlite 'CREATE TABLE fixture_later_work(value); INSERT INTO fixture_later_work VALUES (1);'")
    machine.succeed('mv /var/lib/pi-native-cutover-172/source /var/lib/pi-native-cutover-172/retained-source; mv /var/lib/pi-native-cutover-172/bundle /var/lib/pi-native-cutover-172/retained-bundle; rm /run/pi-native-cutover-172-approved')
    machine.reboot()
    machine.wait_for_shutdown()
    machine.start()
    machine.wait_for_unit('pi-native-cutover-172.service')
    machine.succeed('test -f /run/pi-native-cutover-172/ready.json')
    machine.succeed('test ! -e /var/lib/pi-native-cutover-172/source')
    machine.succeed('/run/current-system/specialisation/start/bin/switch-to-configuration test')
    machine.wait_for_unit('pi-chat-transport.service')
    machine.wait_for_unit('pi-chat-model.service')
    machine.wait_until_succeeds(uctl + 'is-active pi-matrix-bridge.service')
    machine.succeed('test ! -e /var/lib/pi-native-cutover-172/source')
    print('PASS: real PID1/root-owner/group/readonly converter/masks/completion/reboot/sandboxed startup; synthetic data only')
  '';
}
