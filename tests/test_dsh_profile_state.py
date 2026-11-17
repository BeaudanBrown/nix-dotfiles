"""Exercise profile seeding without a DSH build, credentials or live services."""

import json
from pathlib import Path
import stat
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest


SEEDER = Path(__file__).resolve().parents[1] / "modules/services/dsh/seed-profile.py"


class ProfileStateTests(unittest.TestCase):
    def seed(self, source: Path, destination: Path) -> None:
        subprocess.run(
            [sys.executable, str(SEEDER), str(source), str(destination)], check=True
        )

    def template(self, root: Path) -> Path:
        source = root / "template"
        source.mkdir()
        (source / "package.json").write_text(
            json.dumps({"name": "dsh-profile-web", "private": True})
        )
        (source / "cordis.patch.yml").write_text("[]\n")
        (source / "pnpm-workspace.yaml").write_text("packages:\n  - .\n")
        for path in source.iterdir():
            path.chmod(0o444)
        return source

    def test_first_start_copies_readonly_template_as_private_writable_files(
        self,
    ) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.template(root)
            destination = root / "profiles/web"
            self.seed(source, destination)
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o700)
            for original in source.iterdir():
                copied = destination / original.name
                self.assertEqual(copied.read_bytes(), original.read_bytes())
                self.assertEqual(stat.S_IMODE(copied.stat().st_mode), 0o600)
                self.assertFalse(copied.is_symlink())

    def test_acknowledgement_and_settings_survive_restart(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.template(root)
            destination = root / "profiles/web"
            self.seed(source, destination)
            settings = destination / "cordis.patch.yml"
            changed = "- id: welcome\n  config:\n    acknowledgedVersion: test\n"
            # Settings editor uses atomic replacement, not just in-place writes.
            pending = destination / "settings.tmp"
            pending.write_text(changed)
            pending.replace(settings)
            self.seed(source, destination)
            self.assertEqual(settings.read_text(), changed)
            self.assertEqual(len(list(destination.iterdir())), 3)

    def test_existing_empty_mountpoint_can_be_seeded(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.template(root)
            destination = root / "profiles/web"
            destination.mkdir(parents=True)
            self.seed(source, destination)
            self.assertEqual((destination / "cordis.patch.yml").read_text(), "[]\n")

    def test_partial_profile_preserves_existing_file(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.template(root)
            destination = root / "profiles/web"
            destination.mkdir(parents=True)
            (destination / "cordis.patch.yml").write_text("# existing state\n[]\n")
            self.seed(source, destination)
            self.assertEqual(
                (destination / "cordis.patch.yml").read_text(), "# existing state\n[]\n"
            )
            self.assertTrue((destination / "package.json").is_file())


if __name__ == "__main__":
    unittest.main()
