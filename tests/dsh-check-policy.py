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
    "preset-standard",
    "preset-cordis",
    "tool-plugin-manager",
):
    matches = [row for row in rows if row.get("id") == name]
    assert matches and all(row.get("disabled") == "true" for row in matches), name

(registry,) = [row for row in rows if row.get("id") == "agent-preset-registry"]
assert registry["config"]["default"] == "ptc"
for preset in ("ptc", "minimal"):
    (config,) = [row["config"] for row in rows if row.get("id") == f"preset-{preset}"]
    for tool in entries(config["plugins"]):
        if tool.get("id") in ("tool-plugin-manager", "tool-plugin-market"):
            assert tool.get("disabled") == "true", (preset, tool["id"])
