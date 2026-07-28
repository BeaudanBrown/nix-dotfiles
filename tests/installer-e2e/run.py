#!/usr/bin/env python3
"""Rootless QEMU smoke test for encrypted USB provisioning and boot.

The target-install/reboot phase is added after this provisioning seam is stable;
this test already exercises the production provisioner against a real removable
QEMU disk, LUKS formatting, nixos-install, UEFI removable boot, and unlock.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import shlex
import json
import shutil
import subprocess
import time

import pexpect

ROOT = pathlib.Path(__file__).resolve().parents[2]
PASSWORD = "fleet-installer-e2e"
BUILDER_SSH_PORT = "22822"
INSTALLER_SSH_PORT = "22823"
TARGET_SSH_PORT = "22824"
ACTIVE_PID_FILE = ROOT / ".pi/tmp/installer-e2e-active.pid"


def register_active_pid(pid: int | None) -> None:
    ACTIVE_PID_FILE.parent.mkdir(parents=True, exist_ok=True)
    if pid is None:
        ACTIVE_PID_FILE.unlink(missing_ok=True)
    else:
        ACTIVE_PID_FILE.write_text(f"{pid}\n")


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True, timeout=10 * 60).strip()


def wait_for_ssh(key: pathlib.Path, port: str, user: str = "root") -> None:
    command = [
        "ssh",
        "-p",
        port,
        "-i",
        str(key),
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        f"{user}@127.0.0.1",
        "true",
    ]
    for _ in range(180):
        if subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            return
        time.sleep(1)
    raise RuntimeError(f"{user} SSH on port {port} did not become reachable")


def ssh(
    key: pathlib.Path,
    script: str,
    port: str = BUILDER_SSH_PORT,
    user: str = "root",
    timeout: int = 20 * 60,
) -> None:
    subprocess.run(
        [
            "ssh",
            "-tt",
            "-p",
            port,
            "-i",
            str(key),
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            f"{user}@127.0.0.1",
            script,
        ],
        check=True,
        timeout=timeout,
    )


def prepare_fixture_repo(tmp: pathlib.Path, public_ssh_key: str) -> pathlib.Path:
    repo = tmp / "nix-dotfiles"
    shutil.copytree(
        ROOT,
        repo,
        symlinks=True,
        ignore=shutil.ignore_patterns(
            ".git",
            ".direnv",
            ".pi",
            ".pre-commit-config.yaml",
            "result",
            "latest.iso",
            "__pycache__",
        ),
    )
    subprocess.run(["git", "init", "--quiet", "-b", "master", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "config", "user.name", "Installer Test"], check=True)
    subprocess.run(["git", "-C", str(repo), "config", "user.email", "installer@example.invalid"], check=True)

    age_key = repo / "test-master-age-key"
    age_output = subprocess.check_output(["age-keygen", "-o", str(age_key)], text=True, stderr=subprocess.STDOUT)
    master_public = next(line.split()[-1] for line in age_output.splitlines() if "Public key:" in line)

    hosts_path = repo / "modules/host-spec/all-hosts.json"
    hosts = json.loads(hosts_path.read_text())
    hosts["masterKey"] = master_public
    hosts["hostSpecs"]["installer-test"] = {
        "hostName": "installer-test",
        "users": [
            {
                "username": "tester",
                "email": "tester@example.invalid",
                "userFullName": "Installer Test",
                "ageUserKey": master_public,
                "uid": 1000,
            }
        ],
        "wifi": False,
        "ageHostKey": master_public,
        "roots": ["minimal"],
    }
    hosts_path.write_text(json.dumps(hosts, indent=2) + "\n")

    flake = repo / "flake.nix"
    flake.write_text(
        flake.read_text().replace(
            'url = "git+ssh://git@github.com/BeaudanBrown/sops-secrets.git?shallow=1";',
            'url = "path:./test-sops-secrets";',
        )
    )

    disko = repo / "modules/system/disko/installer-test.nix"
    disko.write_text(
        '''{ ... }:
{
  disko.devices = import ./btrfs_luks.nix {
    deviceName = "/dev/disk/by-id/virtio-installer-target";
    swapSize = "1G";
  };
}
'''
    )
    host_dir = repo / "hosts/installer-test"
    host_dir.mkdir()
    (host_dir / "hardware.nix").write_text(
        '''{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" ];
  nixpkgs.hostPlatform = "x86_64-linux";
}
'''
    )
    (host_dir / "default.nix").write_text(
        f'''{{ inputs, lib, ... }}:
{{
  imports = [
    ./hardware.nix
    ../../modules/system/disko/installer-test.nix
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
  ];
  options.hostSpec = lib.mkOption {{ type = lib.types.attrs; }};
  config = {{
    hostSpec.users = [ {{ username = "tester"; home = "/home/tester"; uid = 1000; }} ];
    networking.hostName = "installer-test";
    networking.useDHCP = true;
    services.openssh.enable = true;
    users.users.tester = {{
      isNormalUser = true;
      uid = 1000;
      group = "users";
      hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
      openssh.authorizedKeys.keys = [ {json.dumps(public_ssh_key)} ];
    }};
    users.users.root.hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    boot.kernelParams = [ "console=ttyS0,115200n8" ];
    sops.defaultSopsFile = inputs.sopsSecrets + "/secrets/installer-test.yaml";
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.secrets.fixture.path = "/run/secrets/fixture";
    environment.systemPackages = [ inputs.self.packages.x86_64-linux.fleet-installer ];
    nix.settings = {{
      accept-flake-config = true;
      experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
    }};
    system.stateVersion = "26.05";
  }};
}}
'''
    )

    sops_repo = repo / "test-sops-secrets"
    (sops_repo / "secrets").mkdir(parents=True)
    (sops_repo / ".sops.yaml").write_text(
        f'''keys:
  - &master {master_public}
creation_rules:
  - path_regex: secrets/.*\\.yaml$
    key_groups:
      - age:
          - *master
'''
    )
    (sops_repo / "secrets/installer-test.yaml").write_text("fixture: installed\n")
    env = os.environ | {"SOPS_AGE_KEY_FILE": str(age_key)}
    subprocess.run(
        ["sops", "--encrypt", "--in-place", "secrets/installer-test.yaml"],
        cwd=sops_repo,
        env=env,
        check=True,
    )
    (repo / ".gitignore").write_text((repo / ".gitignore").read_text() + ".test-*-remote.git/\n")
    subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
    subprocess.run(["nix", "flake", "lock"], cwd=repo, check=True)
    subprocess.run(["git", "-C", str(repo), "add", "flake.lock"], check=True)
    subprocess.run(["git", "-C", str(repo), "commit", "--quiet", "-m", "installer test fixture"], check=True)
    dotfiles_remote = repo / ".test-dotfiles-remote.git"
    subprocess.run(["git", "init", "--bare", "--quiet", str(dotfiles_remote)], check=True)
    subprocess.run(["git", "-C", str(repo), "remote", "add", "origin", ".test-dotfiles-remote.git"], check=True)
    subprocess.run(["git", "-C", str(repo), "push", "--quiet", "-u", "origin", "master"], check=True)
    return repo


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provision-only", action="store_true")
    args = parser.parse_args()
    if subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"], capture_output=True, text=True).stdout:
        raise RuntimeError("E2E tests require a clean repository")
    if not os.access("/dev/kvm", os.R_OK | os.W_OK):
        raise RuntimeError("/dev/kvm is not available")

    tmp = ROOT / ".pi/tmp/installer-e2e-last"
    if tmp.exists():
        stale = tmp.with_name(f"installer-e2e-stale-{int(time.time())}")
        tmp.rename(stale)
    tmp.mkdir(parents=True)
    try:
        package_out = pathlib.Path(
            run("nix", "build", "--no-link", "--print-out-paths", f"{ROOT}#fleet-installer")
        )
        shutil.copy2(package_out / "bin/fleet-installer", tmp / "fleet-installer")
        (tmp / "fleet-installer").chmod(0o755)
        iso_out = pathlib.Path(
            run(
                "nix",
                "build",
                "--no-link",
                "--print-out-paths",
                f"{ROOT}#nixosConfigurations.iso.config.system.build.isoImage",
            )
        )
        iso = next((iso_out / "iso").glob("*.iso"))
        ovmf = pathlib.Path(run("nix", "build", "--no-link", "--print-out-paths", "nixpkgs#OVMF.fd")) / "FV"
        vars_path = tmp / "OVMF_VARS.fd"
        shutil.copy2(ovmf / "OVMF_VARS.fd", vars_path)
        vars_path.chmod(0o600)

        usb = tmp / "installer-usb.qcow2"
        target = tmp / "installer-target.qcow2"
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(usb), "40G"], check=True)
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(target), "30G"], check=True)
        fixture_key = tmp / "id_ed25519"
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(fixture_key)], check=True)
        fixture_repo = prepare_fixture_repo(tmp, fixture_key.with_suffix(".pub").read_text().strip())
        (tmp / "headscale-key").write_text("fixture-headscale-key\n")

        pidfile = tmp / "builder.pid"
        qemu = [
            "qemu-system-x86_64",
            "-enable-kvm",
            "-machine",
            "q35,accel=kvm",
            "-cpu",
            "host",
            "-m",
            "8192",
            "-smp",
            "4",
            "-drive",
            f"if=pflash,format=raw,readonly=on,file={ovmf / 'OVMF_CODE.fd'}",
            "-drive",
            f"if=pflash,format=raw,file={vars_path}",
            "-cdrom",
            str(iso),
            "-device",
            "qemu-xhci",
            "-drive",
            f"if=none,id=installerusb,format=qcow2,file={usb}",
            "-device",
            "usb-storage,drive=installerusb,removable=true",
            "-virtfs",
            f"local,path={fixture_repo},mount_tag=repo,security_model=mapped-xattr,readonly=on",
            "-virtfs",
            f"local,path={tmp},mount_tag=fixture,security_model=mapped-xattr,readonly=on",
            "-netdev",
            f"user,id=net0,hostfwd=tcp:127.0.0.1:{BUILDER_SSH_PORT}-:22",
            "-device",
            "virtio-net-pci,netdev=net0",
            "-display",
            "none",
            "-serial",
            f"file:{tmp / 'builder.log'}",
            "-daemonize",
            "-pidfile",
            str(pidfile),
        ]
        subprocess.run(qemu, check=True)
        register_active_pid(int(pidfile.read_text()))
        try:
            # The custom ISO trusts the current fleet key. This key is used only
            # to control the disposable builder VM, never copied to the USB.
            control_key = pathlib.Path.home() / ".ssh/id_ed25519"
            wait_for_ssh(control_key, BUILDER_SSH_PORT)
            script = f"""
set -euo pipefail
mkdir -p /repo /fixture
mount -t 9p -o trans=virtio,version=9p2000.L repo /repo
mount -t 9p -o trans=virtio,version=9p2000.L fixture /fixture
git config --global --add safe.directory /repo
cd /repo
env \\
  FLEET_INSTALLER_TEST_ALLOW_ROOT=1 \\
  FLEET_INSTALLER_TEST_CONFIRM=1 \\
  FLEET_INSTALLER_TEST_ALLOW_DIRTY=1 \\
  FLEET_INSTALLER_TEST_COPY_REPO=1 \\
  FLEET_INSTALLER_TEST_USE_PATH_DISKO=1 \\
  FLEET_INSTALLER_TEST_LUKS_PASSWORD={shlex.quote(PASSWORD)} \\
  FLEET_INSTALLER_TEST_WIFI_PSK=fixture-password \\
  FLEET_INSTALLER_HEADSCALE_KEY_FILE=/fixture/headscale-key \\
  FLEET_INSTALLER_SSH_KEY_FILE=/fixture/id_ed25519 \\
  timeout --signal=TERM --kill-after=15s 25m /fixture/fleet-installer provision-usb
poweroff
"""
            ssh(control_key, script, timeout=27 * 60)
        finally:
            if pidfile.exists():
                try:
                    os.kill(int(pidfile.read_text()), 15)
                except ProcessLookupError:
                    pass
            register_active_pid(None)
        for _ in range(60):
            if not pidfile.exists() or not pathlib.Path(f"/proc/{pidfile.read_text().strip()}").exists():
                break
            time.sleep(1)

        cache = ROOT / ".pi/tmp/installer-e2e-cache"
        cache.mkdir(parents=True, exist_ok=True)
        cache_image = cache / "installer-usb-base.qcow2.tmp"
        subprocess.run(
            ["qemu-img", "convert", "-p", "-O", "qcow2", str(usb), str(cache_image)],
            check=True,
            timeout=5 * 60,
        )
        cache_image.replace(cache / "installer-usb-base.qcow2")
        shutil.copy2(fixture_key, cache / "id_ed25519")
        shutil.copy2(fixture_key.with_suffix(".pub"), cache / "id_ed25519.pub")
        if args.provision_only:
            print(f"provision cache ready: {cache}")
            return

        installer_boot = [
            "qemu-system-x86_64",
            "-enable-kvm",
            "-machine",
            "q35,accel=kvm",
            "-cpu",
            "host",
            "-m",
            "8192",
            "-smp",
            "4",
            "-drive",
            f"if=pflash,format=raw,readonly=on,file={ovmf / 'OVMF_CODE.fd'}",
            "-drive",
            f"if=pflash,format=raw,file={vars_path}",
            "-device",
            "qemu-xhci",
            "-drive",
            f"if=none,id=installerusb,format=qcow2,file={usb}",
            "-device",
            "usb-storage,drive=installerusb,removable=true,bootindex=1",
            "-drive",
            f"if=none,id=target,format=qcow2,file={target}",
            "-device",
            "virtio-blk-pci,drive=target,serial=installer-target",
            "-netdev",
            f"user,id=net0,hostfwd=tcp:127.0.0.1:{INSTALLER_SSH_PORT}-:22",
            "-device",
            "virtio-net-pci,netdev=net0",
            "-nographic",
        ]
        child = pexpect.spawn(installer_boot[0], installer_boot[1:], encoding="utf-8", timeout=300)
        register_active_pid(child.pid)
        with open(tmp / "installer-boot.log", "w") as boot_log:
            child.logfile = boot_log
            try:
                child.expect(["passphrase", "Passphrase"])
                child.sendline(PASSWORD)
                child.expect("Install a detected fleet host: install-host")
                wait_for_ssh(fixture_key, INSTALLER_SSH_PORT, "installer")
                setup_and_install = f"""
set -euo pipefail
cd /var/lib/fleet-installer/nix-dotfiles/test-sops-secrets
git init --quiet -b main
git config user.name 'Installer Test'
git config user.email installer@example.invalid
git add .
git commit --quiet -m 'fixture secrets'
git init --bare --quiet ../.test-sops-remote.git
git remote add origin /var/lib/fleet-installer/nix-dotfiles/.test-sops-remote.git
git push --quiet -u origin main
cd /var/lib/fleet-installer/nix-dotfiles
export FLEET_INSTALLER_TEST_CONFIRM=1
export FLEET_INSTALLER_TEST_HOST=installer-test
export FLEET_INSTALLER_TEST_LUKS_PASSWORD={shlex.quote(PASSWORD)}
export FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO=/var/lib/fleet-installer/nix-dotfiles/test-sops-secrets
export FLEET_INSTALLER_TEST_NO_REBOOT=1
export SOPS_AGE_KEY_FILE=/var/lib/fleet-installer/nix-dotfiles/test-master-age-key
timeout --signal=TERM --kill-after=15s 12m \\
  sudo -n --preserve-env=FLEET_INSTALLER_TEST_CONFIRM,FLEET_INSTALLER_TEST_HOST,FLEET_INSTALLER_TEST_LUKS_PASSWORD,FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO,FLEET_INSTALLER_TEST_NO_REBOOT,SOPS_AGE_KEY_FILE \\
  "$(readlink -f "$(command -v fleet-installer)")" install-host
"""
                ssh(fixture_key, setup_and_install, INSTALLER_SSH_PORT, "installer", 25 * 60)
            finally:
                if child.isalive():
                    child.terminate(force=True)
                register_active_pid(None)

        target_vars = tmp / "TARGET_OVMF_VARS.fd"
        shutil.copy2(ovmf / "OVMF_VARS.fd", target_vars)
        target_vars.chmod(0o600)
        target_boot = [
            "qemu-system-x86_64",
            "-enable-kvm",
            "-machine",
            "q35,accel=kvm",
            "-cpu",
            "host",
            "-m",
            "4096",
            "-smp",
            "2",
            "-drive",
            f"if=pflash,format=raw,readonly=on,file={ovmf / 'OVMF_CODE.fd'}",
            "-drive",
            f"if=pflash,format=raw,file={target_vars}",
            "-drive",
            f"if=none,id=target,format=qcow2,file={target}",
            "-device",
            "virtio-blk-pci,drive=target,serial=installer-target,bootindex=1",
            "-netdev",
            f"user,id=net0,hostfwd=tcp:127.0.0.1:{TARGET_SSH_PORT}-:22",
            "-device",
            "virtio-net-pci,netdev=net0",
            "-nographic",
        ]
        child = pexpect.spawn(target_boot[0], target_boot[1:], encoding="utf-8", timeout=300)
        register_active_pid(child.pid)
        with open(tmp / "target-boot.log", "w") as target_log:
            child.logfile = target_log
            try:
                child.expect(["passphrase", "Passphrase"])
                child.sendline(PASSWORD)
                wait_for_ssh(fixture_key, TARGET_SSH_PORT, "tester")
                ssh(
                    fixture_key,
                    "test -s /run/secrets/fixture && test $(hostname) = installer-test",
                    TARGET_SSH_PORT,
                    "tester",
                )
                child.sendcontrol("a")
                child.send("x")
                child.expect(pexpect.EOF)
            finally:
                if child.isalive():
                    child.terminate(force=True)
                register_active_pid(None)
        print("encrypted USB provision, full target install, SOPS activation, and reboot passed")
    except Exception:
        print(f"E2E artifacts retained in {tmp}")
        raise


if __name__ == "__main__":
    main()
