"""Loopback-only backend for the tailnet HTTPS Grill relay."""

import hmac
import os
import re
import socket
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

DESTINATION = ("192.168.68.255", 9)
PACKET = b"\xff" * 6 + bytes.fromhex("04 d9 f5 05 06 cc") * 16


def send_wake_packet():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(PACKET, DESTINATION)


def request_unlock(ssh, host, port, user, known_hosts, identity):
    return subprocess.run(
        [
            ssh,
            "-4",
            "-F", "none",
            "-nT",
            "-o", "BatchMode=yes",
            "-o", "IdentitiesOnly=yes",
            "-o", "IdentityAgent=none",
            "-o", "PreferredAuthentications=publickey",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "HostKeyAlias=grill-wake-unlock",
            "-o", "HostKeyAlgorithms=ssh-ed25519",
            "-o", "GlobalKnownHostsFile=none",
            "-o", f"UserKnownHostsFile={known_hosts}",
            "-o", "UpdateHostKeys=no",
            "-o", "ClearAllForwardings=yes",
            "-o", "ConnectTimeout=3",
            "-o", "ConnectionAttempts=1",
            "-i", str(identity),
            "-p", port,
            "-l", user,
            "--", host, "unlock",
        ],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=8,
        check=True,
    )


class Handler(BaseHTTPRequestHandler):
    timeout = 5

    def respond(self, status, **headers):
        self.send_response(status)
        for key, value in headers.items():
            self.send_header(key, value)
        self.end_headers()

    def has_body(self):
        return self.headers.get("Transfer-Encoding") is not None or (
            self.headers.get_all("Content-Length") not in (None, ["0"])
        )

    def unlock(self):
        if self.has_body():
            self.respond(400)
            return

        authorization = self.headers.get_all("Authorization", [])
        scheme, _, supplied = (
            authorization[0].partition(" ") if len(authorization) == 1 else ("", "", "")
        )
        if scheme.lower() != "bearer" or not supplied:
            self.respond(401, **{"WWW-Authenticate": "Bearer"})
            return

        try:
            token = (self.server.credentials / "unlock-token").read_bytes().rstrip(b"\r\n")
            if not re.fullmatch(rb"[A-Za-z0-9._~+/-]+=*", token):
                raise ValueError("invalid token credential")
        except (OSError, ValueError):
            self.log_error("Unlock token credential unavailable or invalid")
            self.respond(503)
            return

        if not hmac.compare_digest(token, supplied.encode("latin-1")):
            self.respond(401, **{"WWW-Authenticate": "Bearer"})
            return

        try:
            request_unlock(*self.server.ssh_config, self.server.credentials / "ssh-private-key")
        except subprocess.CalledProcessError as error:
            self.log_error("Grill SSH unlock failed (exit %d)", error.returncode)
            self.respond(503)
        except (OSError, subprocess.TimeoutExpired):
            self.log_error("Grill SSH unlock could not start or timed out")
            self.respond(503)
        else:
            self.respond(202)

    def do_POST(self):
        if self.path == "/grill/unlock":
            self.unlock()
        elif self.path != "/grill":
            self.respond(404)
        elif self.headers.get_all("X-Wake-Grill") != ["1"]:
            self.respond(403)
        elif self.has_body():
            self.respond(400)
        else:
            try:
                send_wake_packet()
            except OSError as error:
                self.log_error("Could not send wake packet: %s", error)
                self.respond(503)
            else:
                self.respond(204)

    def method_not_allowed(self):
        self.respond(405, Allow="POST")

    do_GET = do_HEAD = do_OPTIONS = method_not_allowed


if __name__ == "__main__":
    with HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler) as server:
        server.credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
        server.ssh_config = sys.argv[2:]
        server.serve_forever()
