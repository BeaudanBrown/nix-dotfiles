#!/usr/bin/env python3
"""Operator-invoked project opt-in. Writes only our marked extension, never credentials."""
import argparse
import json
import os
from pathlib import Path

MARKER = '// Managed by vikunja-agent-init; profile selected by the operator.\n'


def initialize(workspace, profile='default', project_id=None, home=None):
    if profile not in ('default', 'full') or (project_id is not None and project_id <= 0):
        raise ValueError('Invalid profile or project ID')
    home = Path(home or Path.home())
    config_root = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
    if not (config_root / 'vikunja-agent' / f'{profile}.json').is_file():
        raise ValueError('Selected host profile is not installed')
    workspace = Path(workspace).absolute()
    workspace.mkdir(parents=True, exist_ok=True)
    # A normal project may itself be a symlink; resolve it once. Do not follow
    # symlinks inside the project when writing the extension.
    workspace = workspace.resolve()
    for directory in (workspace / '.pi', workspace / '.pi/extensions'):
        if directory.is_symlink():
            raise ValueError('Refusing symlinked project configuration directories')
        directory.mkdir(exist_ok=True)
    target = workspace / '.pi/extensions/vikunja.ts'
    if target.is_symlink() or (target.exists() and not target.read_text().startswith(MARKER)):
        raise ValueError('Refusing to replace an unowned extension')
    data_root = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
    source = data_root / 'vikunja-agent/index.ts'
    text = (MARKER + f'import {{ registerVikunja }} from {json.dumps(str(source))};\n'
            'import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";\n'
            f'export default function (pi: ExtensionAPI) {{ registerVikunja(pi, {json.dumps(profile)}, '
            f'{project_id if project_id is not None else "undefined"}); }}\n')
    # O_NOFOLLOW also protects against a symlink substituted after the check.
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as output:
        output.write(text)
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workspace')
    parser.add_argument('--profile', choices=['default', 'full'], default='default')
    parser.add_argument('--project-id', type=int)
    args = parser.parse_args()
    try:
        print(initialize(args.workspace, args.profile, args.project_id))
    except (ValueError, OSError) as error:
        parser.exit(1, f'Cannot initialize Vikunja tools: {error}\n')
