"""Fixed, standard-library publishing protocol. No project commands run on NAS."""
import argparse
import fcntl
import hashlib
import heapq
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid
import zipfile

SOURCE_DIRS = ('content', 'layouts', 'assets', 'static')
CONFIG = '''baseURL = "https://dump.bepis.lol/"
title = "dump"
disableKinds = ["taxonomy", "term", "rss", "sitemap"]
[markup.goldmark.renderer]
unsafe = false
[security.exec]
allow = ["none"]
[security.http]
urls = ["none"]
methods = ["none"]
'''


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, indent=2) + '\n')
    tmp.replace(path)


def inventory(root):
    result = {}
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError(f'Not a regular file/directory: {rel}')
        if any(part.startswith('.') for part in rel.parts):
            raise ValueError(f'Hidden content is not publishable: {rel}')
        if path.is_file():
            if path.name.endswith(('.tmp', '.part', '~')):
                raise ValueError(f'Incomplete file: {rel}')
            with path.open('rb') as stream:
                result[str(rel)] = hashlib.file_digest(stream, 'sha256').hexdigest()
    return result


def metadata(path):
    text = path.read_text()
    try:
        data, _ = json.JSONDecoder().raw_decode(text.lstrip())
    except ValueError as exc:
        raise ValueError(f'{path}: use JSON front matter') from exc
    if not isinstance(data, dict) or not data.get('title'):
        raise ValueError(f'{path}: title required')
    if any(k in data for k in ('url', 'aliases', 'outputs', 'headless', 'build', '_build')):
        raise ValueError(f'{path}: reserved routing/build metadata')
    return data


def validate(root):
    inventory(root)
    for attachment in (root / 'content').rglob('*'):
        if not attachment.is_file():
            continue
        suffix = attachment.suffix.lower()
        if suffix == '.pdf':
            with attachment.open('rb') as stream:
                if stream.read(5) != b'%PDF-':
                    raise ValueError(f'{attachment}: not a PDF (possibly an HTML error page)')
        elif suffix == '.epub':
            try:
                with zipfile.ZipFile(attachment) as archive:
                    info = archive.getinfo('mimetype')
                    if info.file_size != 20 or archive.read(info) != b'application/epub+zip':
                        raise ValueError('invalid EPUB mimetype')
            except (ValueError, KeyError, zipfile.BadZipFile) as exc:
                raise ValueError(f'{attachment}: not an EPUB') from exc
    works = {}
    assignments = []
    for path in (root / 'content').rglob('*.md'):
        data = metadata(path)
        for source in data.get('sources', []):
            if not re.match(r'^https?://[^\s]+$', source['url']):
                raise ValueError(f'{path}: invalid source URL')
        if data.get('type') == 'work':
            work_id = data.get('work_id', '')
            if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', work_id) or work_id in works:
                raise ValueError(f'{path}: invalid/duplicate work_id')
            works[work_id] = path
        assignments.extend(data.get('assignments', []))
    for assignment in assignments:
        if 'instruction' in assignment:
            continue
        if assignment['work'] not in works:
            raise ValueError(f"Unknown work: {assignment['work']}")
    if not (root / 'content/_index.md').is_file():
        raise ValueError('Missing home page')


def copy_source(source, target):
    target.mkdir(parents=True, exist_ok=True)
    for name in SOURCE_DIRS:
        path = source / name
        if path.exists():
            if path.is_symlink():
                raise ValueError(f'Symlink source: {name}')
            before = inventory(path)
            shutil.copytree(path, target / name, symlinks=True)
            if before != inventory(path) or before != inventory(target / name):
                raise ValueError(f'Source changed while snapshotting: {name}; retry')
    # Detect cross-directory edits made after an earlier directory was copied.
    for name in SOURCE_DIRS:
        path = source / name
        if path.exists() != (target / name).exists():
            raise ValueError(f'Source changed while snapshotting: {name}; retry')
        if path.exists() and inventory(path) != inventory(target / name):
            raise ValueError(f'Source changed while snapshotting: {name}; retry')
    validate(target)
    # Snapshots contain only publishable inputs; the separate NAS identity
    # must be able to read them even when the editor uses a private umask.
    target.chmod(0o755)
    for path in target.rglob('*'):
        path.chmod(0o755 if path.is_dir() else 0o644)


def build(source, output, hugo):
    validate(source)
    (source / 'hugo.toml').write_text(CONFIG)
    env = {k: v for k, v in os.environ.items() if not k.startswith('HUGO_')}
    env.update(HUGO_SECURITY_EXEC_ALLOW='none', HUGO_SECURITY_HTTP_URLS='none',
               HUGO_SECURITY_HTTP_METHODS='none')
    subprocess.run([hugo, '--source', str(source), '--destination', str(output),
                    '--config', str(source / 'hugo.toml'), '--noBuildLock',
                    '--cacheDir', str(source / 'cache')], check=True, env=env, timeout=180)
    inventory(output)
    if not (output / 'index.html').is_file():
        raise ValueError('Hugo did not produce index.html')


def mounted_project(project):
    # Access the control directory first to trigger systemd's automount. Merely
    # testing ismount can mistake an autofs placeholder/local subvolume for NFS.
    if not (project / '.publishing/requests').is_dir():
        return False
    for line in Path('/proc/self/mountinfo').read_text().splitlines():
        fields = line.split()
        separator = fields.index('-')
        mountpoint = re.sub(r'\\([0-7]{3})', lambda m: chr(int(m[1], 8)), fields[4])
        if (mountpoint == str(project) and fields[separator + 1] in ('nfs', 'nfs4')
                and fields[separator + 2].endswith(':/var/lib/dump-site/project')):
            return True
    return False


def submit(project, hugo, require_mount=True, queue=None):
    if require_mount and not mounted_project(project):
        raise ValueError('Project is not mounted from the expected NAS NFS export; refusing a local shadow copy')
    queue = queue if queue is not None else project / '.publishing/requests'
    queue.mkdir(parents=True, exist_ok=True)
    request_id = f'{time.time_ns()}-{uuid.uuid4().hex}'
    draft = queue / ('.' + request_id)
    try:
        copy_source(project, draft / 'source')
        manifest = inventory(draft / 'source')
        with tempfile.TemporaryDirectory(prefix='dump-check-') as tmp:
            local = Path(tmp) / 'source'
            shutil.copytree(draft / 'source', local)
            build(local, Path(tmp) / 'public', hugo)
        atomic_json(draft / 'manifest.json', manifest)
        (draft / 'manifest.json').chmod(0o644)
        draft.chmod(0o755)
        draft.rename(queue / request_id)
    except BaseException:
        shutil.rmtree(draft, ignore_errors=True)
        raise
    print(request_id)
    return request_id


def activate(state, request_id):
    release = state / 'releases' / request_id
    if not (release / 'index.html').is_file():
        raise ValueError('Not a complete release')
    link = state / 'next'
    link.unlink(missing_ok=True)
    link.symlink_to(release)
    link.replace(state / 'current')


def consume(project, state, hugo):
    state.mkdir(parents=True, exist_ok=True)
    with (state / 'lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        queue = project / '.publishing/requests'
        for request in sorted(queue.glob('*')):
            request_id = request.name
            if not re.fullmatch(r'[0-9]+-[a-f0-9]{32}', request_id):
                continue
            receipt = state / 'receipts' / (request_id + '.json')
            if receipt.exists():
                status = project / '.publishing/status' / (request_id + '.json')
                if not status.exists():
                    atomic_json(status, json.loads(receipt.read_text()))
                continue
            result = {'id': request_id, 'url': 'https://dump.bepis.lol/'}
            try:
                if request.is_symlink() or (request / 'source').is_symlink() or (request / 'manifest.json').is_symlink():
                    raise ValueError('Symlink request')
                with tempfile.TemporaryDirectory(dir=state, prefix='build-') as tmp:
                    source = Path(tmp) / 'source'
                    copy_source(request / 'source', source)
                    if inventory(source) != json.loads((request / 'manifest.json').read_text()):
                        raise ValueError('Snapshot changed after submission')
                    output = Path(tmp) / 'public'
                    build(source, output, hugo)
                    release = state / 'releases' / request_id
                    release.parent.mkdir(exist_ok=True)
                    # A crash after rename/activation but before the receipt can
                    # leave a complete release. Reuse only identical output.
                    if release.exists():
                        if inventory(release) != inventory(output):
                            raise ValueError('Existing release differs; operator recovery required')
                    else:
                        output.rename(release)
                    activate(state, request_id)
                result['state'] = 'published'
            except Exception as exc:
                result.update(state='failed', error=str(exc))
            atomic_json(receipt, result)
            atomic_json(project / '.publishing/status' / (request_id + '.json'), result)
        # Keep the latest five releases, always retaining the active one.
        current = (state / 'current').resolve()
        releases = sorted((state / 'releases').glob('*'), reverse=True)
        for release in releases[5:]:
            if release != current:
                shutil.rmtree(release)


def sandbox_paths(project):
    """Only the host-packaged executor supplies these canonical mount points.

    This mode is not an exemption for GRILL's normal submit command. The
    executor binds the NAS source plus queue/status separately; file tools
    cannot reach the queue or change the host command argv.
    """
    if project != Path('/workspace') or project.resolve() != project:
        raise ValueError('Local submission requires the approved sandbox workspace')
    queue, status = Path('/commands/data/requests'), Path('/commands/data/status')
    if not all(path.is_dir() and path.resolve() == path for path in (queue, status)):
        raise ValueError('Local submission requires host-owned queue and status mounts')
    return queue, status


def recent_status(status, queue=None):
    receipts = []
    sources = ((p.stem for p in status.glob('*.json')),
               (p.name for p in queue.iterdir()) if queue is not None else ())
    # IDs are sortable; bounded memory even with old receipts retained.
    candidates = heapq.nlargest(20, (name for name in itertools.chain(*sources)
                                    if re.fullmatch(r'[0-9]+-[a-f0-9]{32}', name)))
    for name in sorted(set(candidates), reverse=True)[:10]:
        path = status / (name + '.json')
        if not path.exists():
            receipts.append({'id': name, 'state': 'pending'})
            continue
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 65536:
            continue
        value = json.loads(path.read_text())
        receipts.append({k: value[k] for k in ('id', 'state', 'url', 'error') if k in value})
    return receipts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'submit', 'submit-local', 'status-local', 'consume', 'rollback'])
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--state', type=Path, default=Path('/var/lib/dump-publisher'))
    parser.add_argument('--hugo', default='hugo')
    parser.add_argument('--release')
    parser.add_argument('--wait', type=int, default=300, help='Submit receipt timeout in seconds')
    args = parser.parse_args()
    project = args.project.absolute()
    if args.action == 'check':
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'source'
            copy_source(project, source)
            build(source, Path(tmp) / 'public', args.hugo)
    elif args.action == 'status-local':
        queue, status_dir = sandbox_paths(project)
        print(json.dumps(recent_status(status_dir, queue)))
    elif args.action in ('submit', 'submit-local'):
        if args.action == 'submit-local':
            queue, status_dir = sandbox_paths(project)
            request_id = submit(project, args.hugo, require_mount=False, queue=queue)
        else:
            queue, status_dir = project / '.publishing/requests', project / '.publishing/status'
            request_id = submit(project, args.hugo)
        status = status_dir / (request_id + '.json')
        deadline = time.monotonic() + args.wait
        while time.monotonic() < deadline:
            if status.exists():
                result = json.loads(status.read_text())
                print(json.dumps(result, indent=2))
                if result['state'] != 'published':
                    raise SystemExit(1)
                # A receipt proves NAS has finished reading this snapshot.
                shutil.rmtree(queue / request_id)
                return
            time.sleep(2)
        raise SystemExit(f'Pending: inspect {status}; do not claim publication succeeded')
    elif args.action == 'consume':
        consume(project, args.state, args.hugo)
    else:
        if not args.release or not re.fullmatch(r'[0-9]+-[a-f0-9]{32}', args.release):
            parser.error('--release must name a retained release')
        with (args.state / 'lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            activate(args.state, args.release)


if __name__ == '__main__':
    main()
