import signal
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import unlock


class UnlockTests(unittest.TestCase):
    def test_refuses_other_ssh_commands(self):
        with patch.dict(unlock.os.environ, {"SSH_ORIGINAL_COMMAND": "sh"}), patch.object(
            unlock, "request_unlock"
        ) as request:
            self.assertEqual(unlock.main(), 1)
            request.assert_not_called()

    def test_requires_one_locker_with_a_handler(self):
        cases = [(0, True, False), (1, False, False), (1, True, True), (2, True, False)]
        for count, catches_signal, expected in cases:
            with self.subTest(count=count, catches_signal=catches_signal):
                with tempfile.TemporaryDirectory() as tmp:
                    proc = Path(tmp)
                    for i in range(count):
                        process = proc / str(100 + i)
                        process.mkdir()
                        mask = unlock.SIGUSR1_MASK if catches_signal else 0
                        (process / "status").write_text(f"Name: hyprlock\nSigCgt: {mask:x}\n")
                    with (
                        patch.object(unlock, "Path", return_value=proc),
                        patch.object(unlock, "active_locker", return_value=True),
                        patch.object(unlock.os, "pidfd_open", side_effect=lambda pid: pid + 1000),
                        patch.object(unlock.os, "close") as close,
                        patch.object(unlock.signal, "pidfd_send_signal") as send,
                    ):
                        self.assertEqual(unlock.request_unlock(Path("/hyprlock")), expected)
                    if expected:
                        send.assert_called_once_with(1100, signal.SIGUSR1)
                    else:
                        send.assert_not_called()
                    self.assertEqual(close.call_count, count)


if __name__ == "__main__":
    unittest.main()
