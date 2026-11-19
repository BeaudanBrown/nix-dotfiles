"""Loopback-only backend for the tailnet HTTPS Wake-on-LAN relay."""

import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

DESTINATION = ("192.168.68.255", 9)
PACKET = b"\xff" * 6 + bytes.fromhex("04 d9 f5 05 06 cc") * 16


def send_wake_packet():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(PACKET, DESTINATION)


class Handler(BaseHTTPRequestHandler):
    timeout = 5

    def respond(self, status, **headers):
        self.send_response(status)
        for key, value in headers.items():
            self.send_header(key, value)
        self.end_headers()

    def do_POST(self):
        if self.path != "/grill":
            self.respond(404)
        elif self.headers.get_all("X-Wake-Grill") != ["1"]:
            self.respond(403)
        elif self.headers.get("Transfer-Encoding") is not None or (
            self.headers.get_all("Content-Length") not in (None, ["0"])
        ):
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
        server.serve_forever()
