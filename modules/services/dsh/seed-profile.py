"""Seed a writable DSH profile once, preserving runtime settings on restart."""

import os
from pathlib import Path
import sys
import tempfile


PROFILE_FILES = ("package.json", "cordis.patch.yml", "pnpm-workspace.yaml")


def seed_profile(source: Path, destination: Path) -> None:
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    for name in PROFILE_FILES:
        target = destination / name
        # Do not overwrite existing settings, including operator-managed links.
        if target.exists() or target.is_symlink():
            continue
        # Publish complete files atomically without replacing a concurrent edit.
        with tempfile.NamedTemporaryFile(dir=destination, delete=False) as pending:
            temporary = Path(pending.name)
            try:
                pending.write((source / name).read_bytes())
                pending.flush()
                os.fsync(pending.fileno())
                try:
                    os.link(temporary, target)
                except FileExistsError:
                    pass
            finally:
                temporary.unlink()


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: seed-profile.py SOURCE DESTINATION")
    seed_profile(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
