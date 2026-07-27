#!/usr/bin/env python3
"""Rootless QEMU smoke test for encrypted USB provisioning and boot.

The target-install/reboot phase is added after this provisioning seam is stable;
this test already exercises the production provisioner against a real removable
QEMU disk, LUKS formatting, nixos-install, UEFI removable boot, and unlock.
"""

from __future__ import annotations

import os
import pathlib
import shlex
import shutil
import subprocess
import tempfile
import time

import pexpect

ROOT = pathlib.Path(__file__).resolve().parents[2]
PASSWORD = "fleet-installer-e2e"
SSH_PORT = "22822"


def run(*args: str, **kwargs: object) -> str:
    return subprocess.check_output(args, text=True, **kwargs).strip()


def wait_for_ssh(key: pathlib.Path) -> None:
    command = [
        "ssh",
        "-p",
        SSH_PORT,
        "-i",
        str(key),
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        "root@127.0.0.1",
        "true",
    ]
    for _ in range(180):
        if subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            return
        time.sleep(1)
    raise RuntimeError("installer ISO did not become reachable over SSH")


def ssh(key: pathlib.Path, script: str) -> None:
    subprocess.run(
        [
            "ssh",
            "-tt",
            "-p",
            SSH_PORT,
            "-i",
            str(key),
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "root@127.0.0.1",
            script,
        ],
        check=True,
    )


def main() -> None:
    if subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"], capture_output=True, text=True).stdout:
        raise RuntimeError("E2E tests require a clean repository")
    if not os.access("/dev/kvm", os.R_OK | os.W_OK):
        raise RuntimeError("/dev/kvm is not available")

    with tempfile.TemporaryDirectory(prefix="fleet-installer-e2e-") as raw_tmp:
        tmp = pathlib.Path(raw_tmp)
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

        usb = tmp / "installer-usb.qcow2"
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(usb), "40G"], check=True)
        fixture_key = tmp / "id_ed25519"
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(fixture_key)], check=True)
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
            f"local,path={ROOT},mount_tag=repo,security_model=none,readonly=on",
            "-virtfs",
            f"local,path={tmp},mount_tag=fixture,security_model=none,readonly=on",
            "-netdev",
            f"user,id=net0,hostfwd=tcp:127.0.0.1:{SSH_PORT}-:22",
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
        try:
            # The custom ISO trusts the current fleet key. This key is used only
            # to control the disposable builder VM, never copied to the USB.
            control_key = pathlib.Path.home() / ".ssh/id_ed25519"
            wait_for_ssh(control_key)
            script = f"""
set -euo pipefail
mkdir -p /repo /fixture
mount -t 9p -o trans=virtio,version=9p2000.L repo /repo
mount -t 9p -o trans=virtio,version=9p2000.L fixture /fixture
cd /repo
printf '1\\ny\\n' | env \\
  FLEET_INSTALLER_TEST_ALLOW_ROOT=1 \\
  FLEET_INSTALLER_TEST_ALLOW_DIRTY=1 \\
  FLEET_INSTALLER_TEST_COPY_REPO=1 \\
  FLEET_INSTALLER_TEST_LUKS_PASSWORD={shlex.quote(PASSWORD)} \\
  FLEET_INSTALLER_TEST_WIFI_PSK=fixture-password \\
  FLEET_INSTALLER_HEADSCALE_KEY_FILE=/fixture/headscale-key \\
  FLEET_INSTALLER_SSH_KEY_FILE=/fixture/id_ed25519 \\
  nix run .#fleet-installer -- provision-usb
poweroff
"""
            ssh(control_key, script)
        finally:
            if pidfile.exists():
                try:
                    os.kill(int(pidfile.read_text()), 15)
                except ProcessLookupError:
                    pass
        for _ in range(60):
            if not pidfile.exists() or not pathlib.Path(f"/proc/{pidfile.read_text().strip()}").exists():
                break
            time.sleep(1)

        boot_command = [
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
            f"if=pflash,format=raw,file={vars_path}",
            "-device",
            "qemu-xhci",
            "-drive",
            f"if=none,id=installerusb,format=qcow2,file={usb}",
            "-device",
            "usb-storage,drive=installerusb,removable=true,bootindex=1",
            "-netdev",
            "user,id=net0",
            "-device",
            "virtio-net-pci,netdev=net0",
            "-nographic",
        ]
        child = pexpect.spawn(boot_command[0], boot_command[1:], encoding="utf-8", timeout=180)
        child.logfile = open(tmp / "boot.log", "w")
        child.expect(["passphrase", "Passphrase"])
        child.sendline(PASSWORD)
        child.expect("Install a detected fleet host: install-host")
        child.sendcontrol("a")
        child.send("x")
        child.expect(pexpect.EOF)
        print("encrypted installer USB provisioned, unlocked, and booted successfully")


if __name__ == "__main__":
    main()
