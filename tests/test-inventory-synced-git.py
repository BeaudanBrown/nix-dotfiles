"""Synthetic inventory tests; never scans real user folders."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "inventory", Path(__file__).resolve().parents[1] / "scripts/inventory-synced-git.py")
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InventoryTests(unittest.TestCase):
    def test_discovery_and_refs(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            for root in module.ROOTS:
                (home / root).mkdir()
            repo = home / "documents/project with spaces"
            subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=Test",
                            "-c", "user.email=test@example.invalid", "commit", "-q",
                            "--allow-empty", "-m", "test"], check=True)
            for relative in ("documents/sops-secrets/hidden", "documents/projects/dump"):
                hidden = home / relative
                hidden.mkdir(parents=True)
                (hidden / ".git").mkdir()
            pointer = home / "collab/worktree"
            pointer.mkdir()
            (pointer / ".git").write_text("gitdir: /not/to/be/read\n")
            (home / "monash/link").symlink_to(repo, target_is_directory=True)
            # Inventory must never ask Git to follow config includes.
            with (repo / ".git/config").open("a") as config:
                config.write('\n[include]\npath = /must-not-be-read/config\n')
            subprocess.run(["git", "-C", str(repo), "pack-refs", "--all"], check=True)
            before = (repo / ".git/index").read_bytes()
            report = module.inventory(home)
            self.assertEqual(report["errors"], [])
            self.assertEqual(len(report["repositories"]), 2)
            row = next(r for r in report["repositories"] if r["kind"] == "directory")
            self.assertEqual(row["refs"][0]["name"], "refs/heads/main")
            self.assertEqual(row["headOid"], row["refs"][0]["oid"])
            self.assertEqual((repo / ".git/index").read_bytes(), before)
            self.assertEqual(len(report["skipped"]), 3)

    def test_metadata_error_is_per_repository(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("broken", "valid"):
                repo = Path(tmp) / "documents" / name
                subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (Path(tmp) / "documents/broken/.git/HEAD").unlink()
            report = module.inventory(Path(tmp))
            self.assertEqual(len(report["repositories"]), 2)
            self.assertEqual(sum("error" in r for r in report["repositories"]), 1)

    def test_missing_roots_and_unborn(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "documents/empty"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            report = module.inventory(Path(tmp))
            self.assertEqual(len(report["errors"]), 2)
            self.assertEqual(report["repositories"][0]["refs"], [])
            self.assertIsNone(report["repositories"][0]["headOid"])


if __name__ == "__main__":
    unittest.main()
