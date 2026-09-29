import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('initializer', Path(__file__).parents[1] / 'init-workspace.py')
assert spec is not None and spec.loader is not None
initializer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(initializer)


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.workspace = self.home / 'projects/example'
        self.env = patch.dict(os.environ, {
            'XDG_CONFIG_HOME': str(self.home / '.config'),
            'XDG_DATA_HOME': str(self.home / '.local/share'),
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        self.config = self.home / '.config/vikunja-agent'
        self.config.mkdir(parents=True)
        (self.config / 'default.json').write_text('{}')

    def test_regular_entrypoint_discovered_by_managed_launcher(self):
        target = initializer.initialize(self.workspace, home=self.home)
        self.assertTrue(target.is_file())
        self.assertFalse(target.is_symlink())
        self.assertIn('"default", undefined', target.read_text())
        self.assertNotIn('token', target.read_text())

    def test_full_profile_is_explicit_and_requires_installed_configuration(self):
        with self.assertRaises(ValueError):
            initializer.initialize(self.workspace, 'full', home=self.home)
        (self.config / 'full.json').write_text('{}')
        target = initializer.initialize(self.workspace, 'full', 17, home=self.home)
        self.assertIn('"full", 17', target.read_text())

    def test_reinitialization_and_binding(self):
        target = initializer.initialize(self.workspace, home=self.home)
        initializer.initialize(self.workspace, project_id=42, home=self.home)
        self.assertIn('"default", 42', target.read_text())
        self.assertFalse((self.workspace / 'AGENTS.md').exists())

    def test_refuses_unowned_extension(self):
        target = initializer.initialize(self.workspace, home=self.home)
        target.write_text('operator content')
        with self.assertRaises(ValueError):
            initializer.initialize(self.workspace, home=self.home)
        self.assertEqual(target.read_text(), 'operator content')

    def test_refuses_symlinks(self):
        target = initializer.initialize(self.workspace, home=self.home)
        target.unlink()
        outside = self.home / 'outside'
        outside.write_text('keep')
        target.symlink_to(outside)
        with self.assertRaises(ValueError):
            initializer.initialize(self.workspace, home=self.home)
        self.assertEqual(outside.read_text(), 'keep')
        target.unlink()
        target.parent.rmdir()
        target.parent.symlink_to(self.home)
        with self.assertRaises(ValueError):
            initializer.initialize(self.workspace, home=self.home)

    def test_invalid_project(self):
        with self.assertRaises(ValueError):
            initializer.initialize(self.workspace, project_id=0, home=self.home)
