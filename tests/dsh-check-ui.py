"""VM-only: exchange a disposable launch token without printing it or a cookie."""

from http.client import HTTPConnection
from pathlib import Path
import re


def check():
    log = Path("/var/lib/dsh-agent/service.log").read_text()
    tokens = re.findall(r"[?&]token=([a-zA-Z0-9_-]+)", log)
    if not tokens:
        return False
    conn = HTTPConnection("127.0.0.1", 3080, timeout=5)
    conn.request("GET", "/?token=" + tokens[-1])
    response = conn.getresponse()
    cookie = response.getheader("Set-Cookie", "").partition(";")[0]
    if response.status not in (302, 303, 307) or not cookie:
        return False
    response.read()
    conn.request("GET", "/", headers={"Cookie": cookie})
    response = conn.getresponse()
    return (
        response.status == 200
        and "text/html" in response.getheader("Content-Type", "")
        and b"dsh-native-codex-oauth" in response.read()
        and "typert contributor(s) failed to register" not in log
    )


raise SystemExit(0 if check() else 1)
