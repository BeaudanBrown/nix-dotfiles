"""Routing tests use synthetic declarations, never secrets or the live vault."""

from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "modules/cli/secretspec"))
# The standalone test adds this repository-local source directory above.
from agent_provider import mock_provider  # noqa: E402  # pyright: ignore[reportMissingImports]


class MockRoutingTests(unittest.TestCase):
    def test_nested_project_uses_external_named_file(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "agent/project"
            nested = project / "src/subdirectory"
            nested.mkdir(parents=True)
            (project / "secretspec.toml").write_text('[project]\nname = "demo-app"\n')
            self.assertEqual(
                mock_provider(nested, root / "agent", root / "mocks"),
                f"dotenv:{root}/mocks/demo-app.env",
            )
            self.assertFalse((project / ".env").exists())

    def test_missing_or_outside_manifest_fails(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            agent = root / "agent"
            agent.mkdir()
            for cwd in [root, agent]:
                with self.subTest(cwd=cwd), self.assertRaises(ValueError):
                    mock_provider(cwd, agent, root / "mocks")

    def test_unsafe_project_names_fail(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ["../vault", "/etc/shadow", "foo/bar", "", "a b", ".."]:
                (root / "secretspec.toml").write_text(f'[project]\nname = "{name}"\n')
                with self.subTest(name=name), self.assertRaises(ValueError):
                    mock_provider(root, root, root / "mocks")

    def test_manifest_symlink_cannot_escape_root(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            agent = root / "agent"
            agent.mkdir()
            outside = root / "private.toml"
            outside.write_text('[project]\nname = "outside"\n')
            (agent / "secretspec.toml").symlink_to(outside)
            with self.assertRaises(ValueError):
                mock_provider(agent, agent, root / "mocks")

    def test_nearest_nested_manifest_wins(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            nested = root / "nested"
            nested.mkdir()
            (root / "secretspec.toml").write_text('[project]\nname = "parent"\n')
            (nested / "secretspec.toml").write_text('[project]\nname = "child"\n')
            self.assertEqual(
                mock_provider(nested, root, root / "mocks"),
                f"dotenv:{root}/mocks/child.env",
            )


if __name__ == "__main__":
    unittest.main()
