#!/usr/bin/env python3
"""Read-only Git metadata inventory; JSON output, local or via SSH."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from typing import Any

ROOTS = ("documents", "monash", "collab")


def mounts():
    # Linux mountinfo includes bind mounts, unlike st_dev comparisons alone.
    paths = set()
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        field = line.split()[4]
        paths.add(re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), field))
    return paths


def inventory(home):
    result = {"home": str(home), "repositories": [], "skipped": [], "errors": []}
    mount_paths = mounts()
    def metadata(marker):
        # Parse only refs, never Git config (which can include private files).
        def read(relative):
            target = marker
            for component in Path(relative).parts:
                target = target / component
                if target.is_symlink() or str(target) in mount_paths:
                    raise ValueError("indirect metadata")
            return target.read_text().strip()

        if (marker / "reftable").exists():
            raise ValueError("reftable requires separate inventory")
        refs = {}
        if (marker / "packed-refs").exists():
            for line in read("packed-refs").splitlines():
                if line and not line.startswith(("#", "^")):
                    oid, name = line.split(" ", 1)
                    refs[name] = oid
        refdir = marker / "refs"
        if refdir.is_symlink() or str(refdir) in mount_paths:
            raise ValueError("indirect refs")
        def fail(error):
            raise error

        for current, dirs, files in os.walk(refdir, followlinks=False, onerror=fail):
            for directory in dirs:
                child = Path(current) / directory
                if child.is_symlink() or str(child) in mount_paths:
                    raise ValueError("indirect refs")
            for name in files:
                relative = str((Path(current) / name).relative_to(marker))
                refs[relative] = read(relative)

        def resolve(value, seen=None):
            seen = set() if seen is None else seen
            if value.startswith("ref: "):
                name = value[5:]
                if name in seen:
                    raise ValueError("cyclic ref")
                return resolve(refs.get(name, ""), seen | {name})
            if not value:
                return None
            if not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", value):
                raise ValueError("unsupported ref format")
            return value

        head = read("HEAD")
        return {"head": head[5:] if head.startswith("ref: ") else "detached",
                "headOid": resolve(head),
                "refs": [{"name": name, "oid": resolve(value)} for name, value in sorted(refs.items())]}

    def skip(path, reason):
        result["skipped"].append({"path": str(path), "reason": reason})

    for root_name in ROOTS:
        root = home / root_name
        if root.is_symlink() or str(root) in mount_paths:
            skip(root, "symlink or mount root")
            continue
        if not root.is_dir():
            result["errors"].append({"path": str(root), "error": "missing root"})
            continue

        def walk_error(error):
            result["errors"].append({"path": error.filename, "error": "directory traversal failed"})

        for current, dirs, files in os.walk(root, followlinks=False, onerror=walk_error):
            path = Path(current)
            for name in list(dirs):
                child = path / name
                if (name == "sops-secrets" or child.is_symlink()
                        or str(child) in mount_paths
                        or child == home / "documents/projects/dump"):
                    dirs.remove(name)
                    skip(child, "private secrets, symlink, mount, or excluded dump path")
            marker = path / ".git"
            if ".git" not in dirs and ".git" not in files:
                continue
            if ".git" in dirs:
                dirs.remove(".git")
            row: dict[str, Any] = {"root": root_name, "relativePath": str(path.relative_to(root)),
                   "path": str(path)}
            result["repositories"].append(row)
            if marker.is_symlink() or not marker.is_dir():
                row["kind"] = "gitfile-or-symlink"
                row["note"] = "not inspected; worktree/submodule/external metadata requires separate inventory"
                continue
            row["kind"] = "directory"
            try:
                row.update(metadata(marker))
                row["shallow"] = (marker / "shallow").exists()
                row["alternates"] = None  # External object stores require a separate check.
            except (ValueError, OSError, UnicodeError) as error:
                row["error"] = type(error).__name__ + ": inventory incomplete"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("hosts", nargs="*", help="SSH aliases; no hosts means local inventory")
    parser.add_argument("--home", help="absolute home directory on all targets; default: target user's home")
    args = parser.parse_args()
    if args.home and (not Path(args.home).is_absolute() or "sops-secrets" in Path(args.home).parts):
        parser.error("--home must be absolute and outside sops-secrets")
    if any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.@-]*", h) for h in args.hosts):
        parser.error("hosts must be simple SSH aliases or user@host names")
    if not args.hosts:
        report = inventory(Path(args.home) if args.home else Path.home())
    else:
        report = {}
        source = Path(__file__).read_text()
        for host in args.hosts:
            command = "python3 -"
            if args.home:
                import shlex
                command += " --home " + shlex.quote(args.home)
            try:
                proc = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                                       host, command], input=source, capture_output=True,
                                      text=True, timeout=300)
                if proc.returncode:
                    report[host] = {"error": "SSH or remote inventory failed", "exitCode": proc.returncode}
                else:
                    report[host] = json.loads(proc.stdout)
            except (OSError, subprocess.TimeoutExpired, ValueError):
                report[host] = {"error": "SSH timeout, unavailable command, or invalid response"}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
