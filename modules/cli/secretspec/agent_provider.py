"""Select non-sensitive, host-local mock values for the standard SecretSpec CLI.

This is convenience routing, not authorization. OS isolation keeps real vault
credentials inaccessible even if project code bypasses this wrapper.
"""

import os
from pathlib import Path
import re
import sys
import tomllib


def mock_provider(cwd: Path, root: Path, mock_root: Path) -> str:
    """Resolve the nearest manifest under the shared root, without reading values."""
    cwd = cwd.resolve(strict=True)
    root = root.resolve(strict=True)
    if not cwd.is_relative_to(root):
        raise ValueError("run SecretSpec from a project beneath /agent")
    current = cwd
    while True:
        manifest = current / "secretspec.toml"
        if manifest.exists():
            if not manifest.resolve(strict=True).is_relative_to(root):
                raise ValueError("project manifest must stay beneath /agent")
            with manifest.open("rb") as handle:
                declaration = tomllib.load(handle)
            project: object = declaration.get("project")
            name: object = project.get("name") if isinstance(project, dict) else None
            if not isinstance(name, str) or not re.fullmatch(
                r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", name
            ):
                raise ValueError(
                    "project.name must be a safe, unique project identifier"
                )
            return f"dotenv:{mock_root / (name + '.env')}"
        if current == root:
            raise ValueError("no secretspec.toml found beneath /agent")
        current = current.parent


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("missing packaged SecretSpec executable")
    executable, *args = sys.argv[1:]
    # No manifest/provider override: one predictable selection convention.
    options = args[: args.index("--")] if "--" in args else args
    if any(
        arg in {"-f", "--file", "-p", "--provider"}
        or arg.startswith(("--file=", "--provider="))
        for arg in options
    ):
        raise SystemExit(
            "agent SecretSpec selects its manifest/provider from the current project"
        )
    try:
        provider = mock_provider(
            Path.cwd(), Path("/agent"), Path("/var/lib/agent-mocks")
        )
    except (OSError, ValueError, tomllib.TOMLDecodeError):
        raise SystemExit(
            "agent SecretSpec requires a valid project manifest beneath /agent"
        ) from None
    env = os.environ.copy()
    env.pop("SECRETSPEC_FILE", None)
    env.pop("BW_SESSION", None)
    env["SECRETSPEC_PROVIDER"] = provider
    os.execve(executable, [executable, *args], env)


if __name__ == "__main__":
    main()
