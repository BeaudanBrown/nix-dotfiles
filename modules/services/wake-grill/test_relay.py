import http.client
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import relay


class QuietHandler(relay.Handler):
    def log_message(self, *_):
        pass


class RelayTest(unittest.TestCase):
    auth = "Authorization: Bearer example-test-token"
    ssh = ("/bin/ssh", "192.0.2.1", "2222", "test-user", "/test/known-hosts")

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.credentials = Path(tmp.name)
        (self.credentials / "unlock-token").write_bytes(b"example-test-token\n")
        self.server = SimpleNamespace(credentials=self.credentials, ssh_config=self.ssh)

    def exchange(self, route, *headers, method="POST"):
        client, server = socket.socketpair()
        with client, server:
            request = "\r\n".join([f"{method} {route} HTTP/1.0", *headers, "", ""])
            client.sendall(request.encode("ascii"))
            QuietHandler(server, ("test", 0), self.server)
            with http.client.HTTPResponse(client) as response:
                response.begin()
                return response.status, response.headers

    @patch.object(relay, "request_unlock")
    def test_unlock_submits_only_for_valid_bearer(self, unlock):
        status, _ = self.exchange("/grill/unlock", self.auth, "Content-Length: 0")
        self.assertEqual(status, 202)
        unlock.assert_called_once_with(*self.ssh, self.credentials / "ssh-private-key")

    @patch.object(relay, "request_unlock")
    def test_unlock_rejects_missing_wrong_and_duplicate_auth(self, unlock):
        for headers in [(), ("Authorization: Bearer wrong",), (self.auth, self.auth)]:
            with self.subTest(headers=len(headers)):
                status, response = self.exchange("/grill/unlock", *headers)
                self.assertEqual(status, 401)
                self.assertEqual(response["WWW-Authenticate"], "Bearer")
        unlock.assert_not_called()

    @patch.object(relay, "request_unlock")
    def test_unlock_rejects_body_wrong_path_and_non_post(self, unlock):
        for header in ["Content-Length: 1", "Transfer-Encoding: chunked"]:
            self.assertEqual(self.exchange("/grill/unlock", self.auth, header)[0], 400)
        self.assertEqual(self.exchange("/grill/unlock?cmd=other", self.auth)[0], 404)
        for method in ["GET", "OPTIONS"]:
            status, headers = self.exchange("/grill/unlock", self.auth, method=method)
            self.assertEqual(status, 405)
            self.assertNotIn("Access-Control-Allow-Origin", headers)
        unlock.assert_not_called()

    @patch.object(relay, "request_unlock")
    def test_transport_and_helper_failures_return_unavailable(self, unlock):
        for failure in [
            subprocess.CalledProcessError(1, "ssh"),
            subprocess.CalledProcessError(255, "ssh"),
            subprocess.TimeoutExpired("ssh", 8),
            OSError(),
        ]:
            unlock.side_effect = failure
            self.assertEqual(self.exchange("/grill/unlock", self.auth)[0], 503)

    @patch.object(relay, "request_unlock")
    def test_empty_credential_fails_closed(self, unlock):
        (self.credentials / "unlock-token").write_bytes(b"\n")
        self.assertEqual(self.exchange("/grill/unlock", self.auth)[0], 503)
        unlock.assert_not_called()

    @patch.object(relay, "send_wake_packet")
    def test_existing_wake_behavior(self, wake):
        self.assertEqual(self.exchange("/grill", "X-Wake-Grill: 1")[0], 204)
        self.assertEqual(self.exchange("/grill", self.auth)[0], 403)
        self.assertEqual(self.exchange("/grill", "X-Wake-Grill: 1", "Content-Length: 1")[0], 400)
        wake.assert_called_once_with()

    @patch.object(relay.subprocess, "run")
    def test_ssh_arguments_pin_host_and_identity_without_shell(self, run):
        relay.request_unlock(*self.ssh, self.credentials / "ssh-private-key")
        (args,), kwargs = run.call_args
        self.assertEqual(args[-9:], [
            "-i", str(self.credentials / "ssh-private-key"),
            "-p", "2222", "-l", "test-user", "--", "192.0.2.1", "unlock",
        ])
        self.assertIn("StrictHostKeyChecking=yes", args)
        self.assertIn("UserKnownHostsFile=/test/known-hosts", args)
        self.assertIn("IdentityAgent=none", args)
        self.assertTrue(kwargs["check"])
        self.assertFalse(kwargs.get("shell", False))
        self.assertEqual(kwargs["timeout"], 8)


if __name__ == "__main__":
    unittest.main()
