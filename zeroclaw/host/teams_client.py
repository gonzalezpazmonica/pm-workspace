"""Savia Teams Client — joins meetings, reads transcripts, posts in chat.

Uses Microsoft Graph API. Requires Azure AD app registration with:
  OnlineMeetings.Read.All, Chat.ReadWrite, CallRecords.Read.All, User.Read.All

Config: TEAMS_APP_CLIENT_ID, TEAMS_APP_TENANT_ID, TEAMS_APP_CLIENT_SECRET_FILE
"""
import os
import json
import time
import urllib.request
import urllib.parse
import urllib.error

CONFIG_KEYS = ["TEAMS_APP_CLIENT_ID", "TEAMS_APP_TENANT_ID",
               "TEAMS_APP_CLIENT_SECRET_FILE", "TEAMS_SAVIA_USER_ID"]


def _load_config():
    """Load Teams config from environment or CLAUDE.local.md."""
    cfg = {}
    for key in CONFIG_KEYS:
        cfg[key] = os.environ.get(key, "")
    # Try loading secret from file
    secret_file = cfg.get("TEAMS_APP_CLIENT_SECRET_FILE", "")
    if secret_file and os.path.isfile(os.path.expanduser(secret_file)):
        with open(os.path.expanduser(secret_file)) as f:
            cfg["client_secret"] = f.read().strip()
    else:
        cfg["client_secret"] = ""
    return cfg


def _get_token(cfg):
    """Get OAuth2 token via client credentials flow."""
    tenant = cfg["TEAMS_APP_TENANT_ID"]
    if not tenant or not cfg.get("client_secret"):
        return None
    url = f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token"
    data = urllib.parse.urlencode({
        "client_id": cfg["TEAMS_APP_CLIENT_ID"],
        "client_secret": cfg["client_secret"],
        "scope": "https://graph.microsoft.com/.default",
        "grant_type": "client_credentials",
    }).encode()
    try:
        req = urllib.request.Request(url, data=data, method="POST")
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())["access_token"]
    except (urllib.error.URLError, KeyError):
        return None


def _graph_get(token, endpoint):
    """GET request to Microsoft Graph API."""
    url = f"https://graph.microsoft.com/v1.0{endpoint}"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except (urllib.error.URLError, json.JSONDecodeError):
        return None


def _graph_post(token, endpoint, body):
    """POST request to Microsoft Graph API."""
    url = f"https://graph.microsoft.com/v1.0{endpoint}"
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except (urllib.error.URLError, json.JSONDecodeError):
        return None


class TeamsClient:
    """Connects Savia to Teams meetings via Graph API."""

    def __init__(self):
        self.cfg = _load_config()
        self.token = None

    def connect(self):
        """Authenticate with Azure AD. Returns True if successful."""
        self.token = _get_token(self.cfg)
        return self.token is not None

    def is_configured(self):
        return all(self.cfg.get(k) for k in CONFIG_KEYS[:3])

    def get_upcoming_meetings(self, hours_ahead=4):
        """Get meetings in the next N hours for Savia's user."""
        if not self.token:
            return []
        user_id = self.cfg.get("TEAMS_SAVIA_USER_ID", "me")
        data = _graph_get(self.token,
                          f"/users/{user_id}/onlineMeetings")
        return data.get("value", []) if data else []

    def get_transcript(self, meeting_id):
        """Get transcript for a meeting. Returns list of entries."""
        if not self.token:
            return None
        data = _graph_get(self.token,
                          f"/me/onlineMeetings/{meeting_id}/transcripts")
        if not data or not data.get("value"):
            return None
        transcript_id = data["value"][0]["id"]
        content = _graph_get(self.token,
                             f"/me/onlineMeetings/{meeting_id}"
                             f"/transcripts/{transcript_id}/content")
        return content

    def post_chat_message(self, chat_id, text):
        """Post a message in the meeting chat."""
        if not self.token:
            return None
        body = {
            "body": {
                "contentType": "text",
                "content": text,
            }
        }
        return _graph_post(self.token, f"/chats/{chat_id}/messages", body)

    def post_digest(self, chat_id, digest_text):
        """Post meeting digest summary in chat."""
        return self.post_chat_message(chat_id, f"📋 {digest_text}")

    def status(self):
        return {
            "configured": self.is_configured(),
            "authenticated": self.token is not None,
            "tenant": self.cfg.get("TEAMS_APP_TENANT_ID", "")[:8] + "..."
            if self.cfg.get("TEAMS_APP_TENANT_ID") else "not set",
        }
