#!/usr/bin/env python3
"""Regression check on a disposable socket; never touches the shared server.

Usage: python3 check-session-cleanup.py /absolute/path/to/raw/tmux [mode]
Without mode, test the detach-on-destroy value declared in common.nix.
Pass 'previous' to reproduce the tmux 3.7b crash.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

binary = str(Path(sys.argv[1]).resolve())
mode = sys.argv[2] if len(sys.argv) > 2 else re.search(
    r"^\s*set -g detach-on-destroy (\w+)\s*$",
    Path(__file__).with_name("common.nix").read_text(), re.MULTILINE,
).group(1)
env = dict(os.environ)
env.pop("TMUX", None)
env.pop("TMUX_PANE", None)
with tempfile.TemporaryDirectory(prefix="tmux-session-cleanup-") as root:
    command = [binary, "-S", root + "/socket", "-f", "/dev/null"]

    def tmux(*args, check=True):
        return subprocess.run(command + list(args), env=env, check=check,
                              capture_output=True, text=True, timeout=5).stdout.strip()

    client = None
    try:
        tmux("new-session", "-d", "-s", "default", "sleep 60")
        tmux("new-session", "-d", "-s", "project", "sleep 60")
        tmux("set-option", "-g", "detach-on-destroy", mode)
        pane = tmux("display-message", "-p", "-t", "=project:", "#{pane_pid}")
        client = subprocess.Popen(command + ["-C", "attach-session", "-t", "=default"],
                                  env=env, stdin=subprocess.PIPE,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            if tmux("list-clients", "-F", "#{session_name}") == "default":
                break
            time.sleep(0.02)
        else:
            raise AssertionError("control client did not attach")
        tmux("switch-client", "-t", "=project")
        assert tmux("list-clients", "-F", "#{session_name}") == "project"
        tmux("kill-session", "-t", "=default")
        tmux("has-session", "-t", "=project")
        assert tmux("display-message", "-p", "-t", "=project:", "#{pane_pid}") == pane
        assert tmux("list-clients", "-F", "#{session_name}") == "project"
        print(f"PASS: {mode}: cleanup preserves server, destination pane and client")
    finally:
        if client is not None:
            client.terminate()
            client.wait(timeout=5)
        tmux("kill-server", check=False)
