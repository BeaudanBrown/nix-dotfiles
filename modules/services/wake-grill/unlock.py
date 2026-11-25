"""Forced SSH command for Grill: signal only the running Hyprland locker."""

import os
from pathlib import Path
import signal
import stat
import sys

SIGUSR1_MASK = 1 << (signal.SIGUSR1 - 1)


def active_locker(proc, executable, uid):
    if proc.stat().st_uid != uid or (proc / "exe").resolve(strict=True) != executable:
        return False

    # Hyprlock inherits the compositor's instance from the session that
    # started it. Do not target an orphan (or an unrelated Wayland locker).
    settings = dict(
        item.split(b"=", 1) for item in (proc / "environ").read_bytes().split(b"\0") if b"=" in item
    )
    instance = os.fsdecode(settings.get(b"HYPRLAND_INSTANCE_SIGNATURE", b""))
    if not instance or "/" in instance or instance in {".", ".."}:
        return False
    socket = Path(f"/run/user/{uid}/hypr") / instance / ".socket.sock"
    return stat.S_ISSOCK(socket.stat().st_mode)


def request_unlock(executable):
    uid = os.getuid()
    lockers = []
    try:
        for proc in Path("/proc").iterdir():
            if not proc.name.isdecimal():
                continue
            fd = None
            try:
                fd = os.pidfd_open(int(proc.name))
                if not active_locker(proc, executable, uid):
                    continue
                lockers.append((fd, proc))
                fd = None
            except (ProcessLookupError, FileNotFoundError, PermissionError):
                continue
            finally:
                if fd is not None:
                    os.close(fd)
        if len(lockers) != 1:
            return False
        fd, proc = lockers[0]
        # Before Hyprlock installs its unlock handler, SIGUSR1 would kill it.
        status = dict(line.split(":", 1) for line in (proc / "status").read_text().splitlines())
        if not (int(status.get("SigCgt", "0"), 16) & SIGUSR1_MASK):
            return False
        # A pidfd ensures PID reuse cannot cause delivery to another process.
        signal.pidfd_send_signal(fd, signal.SIGUSR1)
        return True
    except OSError:
        return False
    finally:
        for fd, _ in lockers:
            os.close(fd)


def main():
    if os.environ.get("SSH_ORIGINAL_COMMAND") != "unlock":
        return 1
    if not request_unlock(Path(sys.argv[1]).resolve()):
        print("No unique ready Hyprlock instance", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
