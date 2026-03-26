#!/usr/bin/env python3
"""Savia Browser Daemon — account loading and DOM extraction helpers."""
import json
import sys
from pathlib import Path

SAVIA_DIR = Path.home() / ".savia"
OUTPUT_DIR = SAVIA_DIR / "outlook-inbox"
COMMANDS_DIR = SAVIA_DIR / "browser-commands"
SIGNAL = SAVIA_DIR / "browser-ready.signal"
ACCOUNTS_FILE = SAVIA_DIR / "mail-accounts.json"

KEEPALIVE_INTERVAL = 900  # 15 min


def load_account(alias):
    with open(ACCOUNTS_FILE, "r") as f:
        accounts = json.load(f)
    if alias not in accounts:
        print(f"Unknown account: {alias}. Check {ACCOUNTS_FILE}")
        sys.exit(1)
    return accounts[alias]


def extract_emails(page):
    return page.evaluate("""() => {
        const results = [];
        document.querySelectorAll('[draggable="true"]').forEach(el => {
            const text = (el.innerText || '').trim();
            if (text.length > 10) results.push(text.substring(0, 500));
        });
        return results.slice(0, 25);
    }""")


def extract_calendar(page):
    return page.evaluate("""() => {
        const results = [];
        document.querySelectorAll(
            '[role="listitem"], [role="button"][aria-label]'
        ).forEach(el => {
            const label = el.getAttribute('aria-label') || '';
            const text = (el.innerText || '').trim();
            const c = label.length > text.length ? label : text;
            const skip = ['Nuevo evento', 'New event', 'Iniciador', 'Correo',
                'Calendario', 'Contactos', 'Boletines', 'Org Explorer',
                'OneDrive', 'Posponer', 'Descartar'];
            if (c.length > 15 && !skip.some(k => c.includes(k)))
                results.push(c.substring(0, 400));
        });
        return results;
    }""")
