"""ZeroClaw PII + Storage + Cleanup gates — split from guardrails.py."""
import os
import re
import time
import json

# ── Gate 3: PII detection in transcripts (before persistence) ──

PII_PATTERNS = [
    (r'\b\d{8}[A-Z]\b', "DNI/NIF detected"),
    (r'\b[A-Z]{2}\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b', "IBAN"),
    (r'\b\d{3}[-.]?\d{3}[-.]?\d{3}\b', "phone number pattern"),
    (r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b', "email"),
    (r'\b\d{16}\b', "possible card number"),
]


def gate_pii(text):
    """FLAG (not block) PII in text. Returns (has_pii, findings)."""
    findings = []
    for pattern, label in PII_PATTERNS:
        if re.search(pattern, text):
            findings.append(label)
    return len(findings) > 0, findings


# ── Gate 4: Raw data auto-expiry (enforce deletion) ──

def gate_raw_cleanup(raw_dir):
    """DELETE raw files older than 1 hour. Runs deterministically."""
    if not os.path.isdir(raw_dir):
        return 0
    deleted = 0
    cutoff = time.time() - 3600
    for root, dirs, files in os.walk(raw_dir):
        for f in files:
            path = os.path.join(root, f)
            try:
                if os.path.getmtime(path) < cutoff:
                    os.remove(path)
                    deleted += 1
            except OSError:
                pass
    return deleted


# ── Gate 5: Storage quota (prevent disk fill) ──

MAX_RAW_DIR_MB = 100


def gate_storage(base_dir, max_mb=MAX_RAW_DIR_MB):
    """BLOCK new data if storage exceeds quota. Returns (ok, reason)."""
    if not os.path.isdir(base_dir):
        return True, "ok"
    total = 0
    for root, _, files in os.walk(base_dir):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    total_mb = total / (1024 * 1024)
    if total_mb > max_mb:
        return False, f"BLOCKED: storage {total_mb:.1f}MB exceeds {max_mb}MB"
    return True, "ok"


# ── Gate 7: Audit log (immutable, append-only) ──

def audit_log(event_type, details, log_dir=None):
    """Append to immutable audit log. Cannot be disabled."""
    if log_dir is None:
        log_dir = os.path.expanduser("~/.savia/zeroclaw")
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "audit.jsonl")
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "type": event_type,
        "details": details,
    }
    with open(log_path, "a") as f:
        f.write(json.dumps(entry) + "\n")
