"""Nextcloud Talk integration for SaviaClaw — send messages autonomously.
Reads credentials from ~/.savia/nextcloud-config (never in repo).
"""
import os
import urllib.request
import urllib.parse
import json
import base64

CONFIG_FILE = os.path.expanduser("~/.savia/nextcloud-config")


def _load_config():
    """Load NC config from local file."""
    if not os.path.isfile(CONFIG_FILE):
        return None
    cfg = {}
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg


def send_message(text, room_token=None):
    """Send a message to Nextcloud Talk. Returns True on success."""
    cfg = _load_config()
    if not cfg:
        return False
    url = cfg.get("NC_URL", "http://localhost")
    user = cfg.get("NC_USER", "savia")
    passwd = cfg.get("NC_PASS", "")
    token = room_token or cfg.get("NC_TALK_TOKEN_MONICA", "")
    if not token or not passwd:
        return False

    endpoint = f"{url}/ocs/v2.php/apps/spreed/api/v1/chat/{token}?format=json"
    data = urllib.parse.urlencode({"message": text[:1000]}).encode()
    auth = base64.b64encode(f"{user}:{passwd}".encode()).decode()

    req = urllib.request.Request(endpoint, data=data, method="POST",
        headers={"OCS-APIRequest": "true", "Authorization": f"Basic {auth}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read())
            return body.get("ocs", {}).get("meta", {}).get("status") == "ok"
    except Exception:
        return False


def read_messages(room_token=None, limit=5):
    """Read recent messages from a Talk room."""
    cfg = _load_config()
    if not cfg:
        return []
    url = cfg.get("NC_URL", "http://localhost")
    user = cfg.get("NC_USER", "savia")
    passwd = cfg.get("NC_PASS", "")
    token = room_token or cfg.get("NC_TALK_TOKEN_MONICA", "")
    if not token or not passwd:
        return []

    endpoint = f"{url}/ocs/v2.php/apps/spreed/api/v1/chat/{token}?format=json&limit={limit}&lookIntoFuture=0"
    auth = base64.b64encode(f"{user}:{passwd}".encode()).decode()

    req = urllib.request.Request(endpoint, headers={
        "OCS-APIRequest": "true", "Authorization": f"Basic {auth}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read())
            messages = body.get("ocs", {}).get("data", [])
            return [{"actor": m.get("actorDisplayName", ""),
                     "message": m.get("message", ""),
                     "ts": m.get("timestamp", 0)} for m in messages]
    except Exception:
        return []


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        ok = send_message(" ".join(sys.argv[1:]))
        print(f"Sent: {ok}")
    else:
        msgs = read_messages()
        for m in msgs:
            print(f"[{m['actor']}] {m['message']}")
