import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('publish', Path(__file__).with_name('publish.py'))
assert spec is not None and spec.loader is not None
pub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)


class PublishingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.project = self.root / 'project'
        (self.project / 'content').mkdir(parents=True)
        (self.project / 'content/_index.md').write_text('{"title":"Home"}\nHello')
        self.state = self.root / 'state'
        self.hugo = self.root / 'hugo'
        self.hugo.write_text('#!/usr/bin/env python3\nimport pathlib,sys\np=pathlib.Path(sys.argv[sys.argv.index("--destination")+1]);p.mkdir();(p/"index.html").write_text("ok")\n')
        self.hugo.chmod(0o755)

    def submit(self):
        return pub.submit(self.project, str(self.hugo), require_mount=False)

    def consume(self):
        pub.consume(self.project, self.state, str(self.hugo))

    def receipt(self, name):
        return json.loads((self.state / 'receipts' / (name + '.json')).read_text())

    def test_publish_and_idempotence(self):
        name = self.submit()
        self.consume()
        self.assertEqual(self.receipt(name)['state'], 'published')
        current = (self.state / 'current').readlink()
        self.consume()
        self.assertEqual((self.state / 'current').readlink(), current)
        self.assertEqual((current / 'index.html').read_text(), 'ok')

    def test_failed_build_keeps_current(self):
        good = self.submit(); self.consume()
        bad = self.submit()
        self.hugo.write_text('#!/usr/bin/env python3\nraise SystemExit(1)\n')
        self.consume()
        self.assertEqual(self.receipt(bad)['state'], 'failed')
        self.assertEqual((self.state / 'current').resolve().name, good)

    def test_mutated_snapshot_rejected(self):
        name = self.submit()
        (self.project / '.publishing/requests' / name / 'source/content/_index.md').write_text('{"title":"Changed"}')
        self.consume()
        self.assertEqual(self.receipt(name)['state'], 'failed')
        self.assertFalse((self.state / 'current').exists())

    def test_private_files_not_submitted(self):
        (self.project / 'inbox').mkdir()
        (self.project / 'inbox/secret.txt').write_text('private')
        (self.project / 'AGENTS.md').write_text('private instructions')
        name = self.submit()
        snapshot = self.project / '.publishing/requests' / name / 'source'
        self.assertFalse((snapshot / 'inbox').exists())
        self.assertFalse((snapshot / 'AGENTS.md').exists())

    def test_symlinks_and_partial_uploads_rejected(self):
        link = self.project / 'content/leak'
        link.symlink_to('/etc/passwd')
        with self.assertRaises(ValueError): self.submit()
        link.unlink()
        (self.project / 'content/book.pdf.part').write_text('unfinished')
        with self.assertRaises(ValueError): self.submit()

    def test_unknown_work_rejected(self):
        (self.project / 'content/week.md').write_text(json.dumps({'title':'Week', 'assignments':[{'work':'missing'}]}))
        with self.assertRaises(ValueError): self.submit()

    def test_download_error_page_rejected(self):
        (self.project / 'content/book.pdf').write_text('<html>not found</html>')
        with self.assertRaisesRegex(ValueError, 'not a PDF'): self.submit()

    def test_interrupted_receipt_recovery(self):
        name = self.submit(); self.consume()
        (self.state / 'receipts' / (name + '.json')).unlink()
        self.consume()
        self.assertEqual(self.receipt(name)['state'], 'published')

    def test_unmounted_project_rejected(self):
        with self.assertRaisesRegex(ValueError, 'not mounted'):
            pub.submit(self.project, str(self.hugo))

    def test_only_expected_nfs_mount_is_accepted(self):
        (self.project / '.publishing/requests').mkdir(parents=True)
        prefix = f'1 0 0:1 / {self.project} rw - '
        for suffix, expected in [
            ('autofs systemd-1 rw', False),
            ('ext4 /dev/sda1 rw', False),
            ('nfs4 nas:/wrong rw', False),
            ('nfs4 nas:/var/lib/dump-site/project rw', True),
        ]:
            with patch.object(Path, 'read_text', return_value=prefix + suffix):
                self.assertEqual(pub.mounted_project(self.project), expected)

    def test_rollback(self):
        first = self.submit(); self.consume()
        second = self.submit(); self.consume()
        self.assertEqual((self.state / 'current').resolve().name, second)
        pub.activate(self.state, first)
        self.assertEqual((self.state / 'current').resolve().name, first)

    def test_status_repaired(self):
        name = self.submit(); self.consume()
        status = self.project / '.publishing/status' / (name + '.json')
        status.unlink(); self.consume()
        self.assertEqual(json.loads(status.read_text())['state'], 'published')

    def test_local_queue_is_separate_from_editable_project(self):
        queue = self.root / 'host-queue'
        name = pub.submit(self.project, str(self.hugo), require_mount=False, queue=queue)
        self.assertTrue((queue / name / 'source/content/_index.md').is_file())
        self.assertFalse((self.project / '.publishing').exists())
        status = self.root / 'status'
        status.mkdir()
        self.assertEqual(pub.recent_status(status, queue), [{'id': name, 'state': 'pending'}])
        (status / (name + '.json')).write_text(json.dumps({'id': name, 'state': 'published'}))
        self.assertEqual(pub.recent_status(status, queue), [{'id': name, 'state': 'published'}])

    def test_local_cli_requires_canonical_sandbox_mounts(self):
        with self.assertRaisesRegex(ValueError, 'approved sandbox'):
            pub.sandbox_paths(self.project)
        with patch.object(Path, 'resolve', return_value=Path('/workspace')):
            with patch.object(Path, 'is_dir', return_value=False):
                with self.assertRaisesRegex(ValueError, 'host-owned'):
                    pub.sandbox_paths(Path('/workspace'))

    def test_source_changes_during_copy_rejected(self):
        original = pub.shutil.copytree
        def changing(source, target, **kwargs):
            result = original(source, target, **kwargs)
            (source / '_index.md').write_text('{"title":"Changed"}')
            return result
        with patch.object(pub.shutil, 'copytree', changing):
            with self.assertRaisesRegex(ValueError, 'changed while snapshotting'): self.submit()


if __name__ == '__main__':
    unittest.main()
