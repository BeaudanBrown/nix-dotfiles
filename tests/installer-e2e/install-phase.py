#!/usr/bin/env python3
"""Run only the target-install phase from a cached encrypted installer USB."""

from __future__ import annotations

import argparse
import os
import pathlib
import shlex
import shutil
import subprocess
import sys
import time

import pexpect

ROOT = pathlib.Path(__file__).resolve().parents[2]
PASSWORD = "fleet-installer-e2e"
INSTALLER_PORT = "22823"
TARGET_PORT = "22824"
ACTIVE_PID = ROOT / ".pi/tmp/installer-e2e-active.pid"


def output(*args: str) -> str:
    return subprocess.check_output(args, text=True, timeout=2 * 60).strip()


def register(pid: int | None) -> None:
    ACTIVE_PID.parent.mkdir(parents=True, exist_ok=True)
    if pid is None:
        ACTIVE_PID.unlink(missing_ok=True)
    else:
        ACTIVE_PID.write_text(f"{pid}\n")


def wait_for_ssh(key: pathlib.Path, port: str, user: str, timeout: int = 90) -> None:
    command = [
        "ssh",
        "-p",
        port,
        "-i",
        str(key),
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=2",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        f"{user}@127.0.0.1",
        "true",
    ]
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5).returncode == 0:
            return
        time.sleep(1)
    raise TimeoutError(f"{user} SSH on port {port} was not ready within {timeout}s")


def ssh_logged(
    key: pathlib.Path,
    port: str,
    user: str,
    script: str,
    log_path: pathlib.Path,
    timeout: int,
) -> None:
    command = [
        "ssh",
        "-tt",
        "-p",
        port,
        "-i",
        str(key),
        "-o",
        "ConnectTimeout=3",
        "-o",
        "ServerAliveInterval=10",
        "-o",
        "ServerAliveCountMax=3",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        f"{user}@127.0.0.1",
        script,
    ]
    with log_path.open("w") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    if result.returncode != 0:
        tail = "\n".join(log_path.read_text(errors="replace").splitlines()[-120:])
        raise RuntimeError(f"SSH install phase failed with {result.returncode}; tail of {log_path}:\n{tail}")


def qemu_base(ovmf: pathlib.Path, vars_path: pathlib.Path) -> list[str]:
    return [
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
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--usb-base",
        type=pathlib.Path,
        default=ROOT / ".pi/tmp/installer-e2e-cache/installer-usb-base.qcow2",
    )
    parser.add_argument(
        "--fixture-key",
        type=pathlib.Path,
        default=ROOT / ".pi/tmp/installer-e2e-cache/id_ed25519",
    )
    args = parser.parse_args()

    if subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"], capture_output=True, text=True).stdout:
        raise RuntimeError("install-phase requires a clean repository")
    if not args.usb_base.is_file() or not args.fixture_key.is_file():
        raise FileNotFoundError("cached USB/key missing; run the provisioning phase first")

    work = ROOT / ".pi/tmp/installer-e2e-install"
    if work.exists():
        stale = work.with_name(f"installer-e2e-install-stale-{int(time.time())}")
        work.rename(stale)
    work.mkdir(parents=True)

    ovmf = pathlib.Path(output("nix", "build", "--no-link", "--print-out-paths", "nixpkgs#OVMF.fd")) / "FV"
    vars_path = work / "OVMF_VARS.fd"
    shutil.copy2(ovmf / "OVMF_VARS.fd", vars_path)
    vars_path.chmod(0o600)

    usb = work / "installer-usb.qcow2"
    target = work / "installer-target.qcow2"
    subprocess.run(
        [
            "qemu-img",
            "create",
            "-q",
            "-f",
            "qcow2",
            "-F",
            "qcow2",
            "-b",
            str(args.usb_base.resolve()),
            str(usb),
        ],
        check=True,
        timeout=15,
    )
    subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(target), "30G"], check=True, timeout=15)

    installer_command = qemu_base(ovmf, vars_path) + [
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
        f"user,id=net0,hostfwd=tcp:127.0.0.1:{INSTALLER_PORT}-:22",
        "-device",
        "virtio-net-pci,netdev=net0",
        "-nographic",
    ]
    child = pexpect.spawn(installer_command[0], installer_command[1:], encoding="utf-8", timeout=240)
    register(child.pid)
    try:
        with (work / "installer-boot.log").open("w") as serial:
            child.logfile = serial
            child.expect(["passphrase", "Passphrase"])
            child.sendline(PASSWORD)
            child.expect("Install a detected fleet host: install-host")
            wait_for_ssh(args.fixture_key, INSTALLER_PORT, "installer")

            script = f"""
set -euo pipefail
repo=/var/lib/fleet-installer/nix-dotfiles
cd "$repo"
git reset --hard origin/master
git clean -fd
rm -rf test-sops-secrets/.git .test-sops-remote.git
cd test-sops-secrets
git init --quiet -b main
git config user.name 'Installer Test'
git config user.email installer@example.invalid
git add .
git commit --quiet -m 'fixture secrets'
git init --bare --quiet ../.test-sops-remote.git
git remote add origin "$repo/.test-sops-remote.git"
git push --quiet -u origin main
cd "$repo"
export FLEET_INSTALLER_TEST_CONFIRM=1
export FLEET_INSTALLER_TEST_HOST=installer-test
export FLEET_INSTALLER_TEST_LUKS_PASSWORD={shlex.quote(PASSWORD)}
export FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO="$repo/test-sops-secrets"
export FLEET_INSTALLER_TEST_NO_REBOOT=1
export SOPS_AGE_KEY_FILE="$repo/test-master-age-key"
printf 'fleet-installer path: '
readlink -f "$(command -v fleet-installer)"
sudo -n -l
timeout --signal=TERM --kill-after=15s 12m \\
  sudo -n --preserve-env=FLEET_INSTALLER_TEST_CONFIRM,FLEET_INSTALLER_TEST_HOST,FLEET_INSTALLER_TEST_LUKS_PASSWORD,FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO,FLEET_INSTALLER_TEST_NO_REBOOT,SOPS_AGE_KEY_FILE \\
  "$(readlink -f "$(command -v fleet-installer)")" install-host
"""
            ssh_logged(
                args.fixture_key,
                INSTALLER_PORT,
                "installer",
                script,
                work / "install-ssh.log",
                13 * 60,
            )
    finally:
        if child.isalive():
            child.terminate(force=True)
        register(None)

    target_vars = work / "TARGET_OVMF_VARS.fd"
    shutil.copy2(ovmf / "OVMF_VARS.fd", target_vars)
    target_vars.chmod(0o600)
    target_command = qemu_base(ovmf, target_vars) + [
        "-drive",
        f"if=none,id=target,format=qcow2,file={target}",
        "-device",
        "virtio-blk-pci,drive=target,serial=installer-target,bootindex=1",
        "-netdev",
        f"user,id=net0,hostfwd=tcp:127.0.0.1:{TARGET_PORT}-:22",
        "-device",
        "virtio-net-pci,netdev=net0",
        "-nographic",
    ]
    child = pexpect.spawn(target_command[0], target_command[1:], encoding="utf-8", timeout=240)
    register(child.pid)
    try:
        with (work / "target-boot.log").open("w") as serial:
            child.logfile = serial
            child.expect(["passphrase", "Passphrase"])
            child.sendline(PASSWORD)
            wait_for_ssh(args.fixture_key, TARGET_PORT, "tester")
            ssh_logged(
                args.fixture_key,
                TARGET_PORT,
                "tester",
                "test -s /run/secrets/fixture && test $(hostname) = installer-test",
                work / "target-assert.log",
                30,
            )
            child.sendcontrol("a")
            child.send("x")
            child.expect(pexpect.EOF, timeout=30)
    finally:
        if child.isalive():
            child.terminate(force=True)
        register(None)
    print("cached install phase passed: Disko, nixos-install, target unlock, SSH, and SOPS")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"install phase failed: {error}", file=sys.stderr)
        print(f"artifacts: {ROOT / '.pi/tmp/installer-e2e-install'}", file=sys.stderr)
        raise
