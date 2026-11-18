"""Check the composed Cordis entry list, tolerating upstream !!js scalars."""

from pathlib import Path
import sys

import yaml


def entries(rows):
    for row in rows:
        yield row
        if isinstance(row.get("config"), list) and row.get("group") == "true":
            yield from entries(row["config"])


rows = list(entries(yaml.load(Path(sys.argv[1]).read_text(), Loader=yaml.BaseLoader)))
for name in (
    "session-log-deepseek",
    "session-telemetry-otel",
    "plugin-manager",
    "ui-plugin-manager",
    "tool-plugin-manager",
):
    matches = [row for row in rows if row.get("id") == name]
    assert matches and all(row.get("disabled") == "true" for row in matches), name
