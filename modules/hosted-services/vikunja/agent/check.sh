#!/usr/bin/env bash
# Offline checks only. No Nix invocation, credentials, service access or LLM call.
set -euo pipefail
cd "$(dirname "$0")"
: "${PI_SDK_ROOT:?Set PI_SDK_ROOT to the installed pi-coding-agent package directory}"
export PI_SDK_ROOT
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export VIKUNJA_CHECK_CONFIG="$scratch/tsconfig.json"
python3 - <<'PY'
import json, os
from pathlib import Path
root = Path.cwd()
sdk = Path(os.environ['PI_SDK_ROOT'])
config = {
  'compilerOptions': {
    'target': 'ES2022', 'module': 'NodeNext', 'moduleResolution': 'NodeNext',
    'strict': True, 'skipLibCheck': True, 'noEmit': True,
    'allowImportingTsExtensions': True,
    'typeRoots': [str(sdk / 'node_modules/@types')],
    'paths': {
      '@earendil-works/pi-coding-agent': [str(sdk / 'dist/index.d.ts')],
      '@earendil-works/pi-ai': [str(sdk / 'node_modules/@earendil-works/pi-ai/dist/index.d.ts')],
      'typebox': [str(sdk / 'node_modules/typebox/build/index.d.mts')],
    },
  },
  'files': [str(root / 'client.ts'), str(root / 'index.ts'), str(root / 'tests/client.test.ts')],
}
Path(os.environ['VIKUNJA_CHECK_CONFIG']).write_text(json.dumps(config))
PY
tsc --project "$VIKUNJA_CHECK_CONFIG"
node --test tests/*.test.ts tests/*.test.mjs
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p '*_test.py'
