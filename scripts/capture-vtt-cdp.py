#!/usr/bin/env python3
"""Savia VTT Capture via CDP — Conecta a un Chrome del SO ya autenticado.

A diferencia de capture-vtt.py, este script NO lanza un Chromium de Playwright.
Se conecta a un Chrome del sistema operativo que ya esta corriendo con
--remote-debugging-port. El Chrome del SO hereda la configuracion de red/VPN
del sistema, resuelve DNS corporativos y tiene la sesion SharePoint ya
autenticada en su user-data-dir dedicado.

Prerequisito:
    Lanzar el Chrome CDP una vez por sesion:
        .\\scripts\\launch-capture-chrome.ps1

    O reutilizar uno de los browser-daemon ya activos en 9222/9223 con
    --cdp-port 9222 (o 9223).

Uso:
    python scripts/capture-vtt-cdp.py <url_video> <path_salida.vtt>
    python scripts/capture-vtt-cdp.py --list-recent [--days N] [--cdp-port P] [--output FILE]

Modo --list-recent:
    Lista grabaciones (.mp4 / .webm / video files) de SharePoint en los ultimos
    N dias (default 7). Util para alimentar el agent-sharepoint del pipeline
    /project-update sin descargar nada.

Salida (modo captura):
    0 = VTT capturada y guardada
    1 = No se capturo (verificar panel transcripcion o autenticacion)
    2 = Uso incorrecto
    3 = No hay Chrome CDP corriendo

Salida (modo --list-recent): JSON con `{"items": [...], "count": N}` a stdout.
"""
import os
import sys
import time
from pathlib import Path

os.environ["PYTHONUTF8"] = "1"

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("ERROR: playwright no instalado. pip install playwright", file=sys.stderr)
    sys.exit(2)

import urllib.request
import urllib.error

CDP_URL = "http://localhost:9224"
NAV_TIMEOUT_MS = 60000
PANEL_WAIT_MS = 3000
VTT_WAIT_MS = 15000

VTT_URL_PATTERNS = (
    "vttcontent",
    "transcriptcontent",
    "/transcript",
    ".vtt",
    "streamingReferrer",
)


def is_vtt_url(url):
    if not url:
        return False
    low = url.lower()
    return any(p in low for p in VTT_URL_PATTERNS)


def is_vtt_body(body):
    if not body:
        return False
    head = body[:500]
    return b"WEBVTT" in head or b"<c>" in head or b"<v " in head


def try_open_transcript_panel(page):
    """Intenta abrir el panel de transcripcion en el reproductor SharePoint."""
    candidates = [
        'button[aria-label*="ranscripci"]',
        'button[aria-label*="ranscript"]',
        'button[title*="ranscripci"]',
        'button[title*="ranscript"]',
        '[data-automationid*="Transcript"]',
        '[data-test-id*="transcript"]',
    ]
    for sel in candidates:
        try:
            el = page.query_selector(sel)
            if el:
                el.click()
                page.wait_for_timeout(PANEL_WAIT_MS)
                return True
        except Exception:
            continue
    return False


def check_cdp_alive():
    """Verifica que el Chrome CDP esta corriendo y accesible."""
    try:
        with urllib.request.urlopen(CDP_URL + "/json/version", timeout=3) as resp:
            data = resp.read().decode("utf-8", errors="ignore")
            if "webSocketDebuggerUrl" in data:
                return True
    except (urllib.error.URLError, TimeoutError, ConnectionRefusedError):
        return False
    return False


def capture(video_url, out_path):
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    if not check_cdp_alive():
        print(
            f"ERROR: no hay Chrome CDP en {CDP_URL}.\n"
            "       Lanza primero: .\\scripts\\launch-capture-chrome.ps1",
            file=sys.stderr,
        )
        return 3

    captured = {"url": None, "body": None}

    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP_URL)
        # Usar contexto existente (tiene cookies de sesion) si hay alguno
        ctx = browser.contexts[0] if browser.contexts else browser.new_context()
        page = ctx.new_page()

        def on_response(response):
            if captured["body"]:
                return
            if is_vtt_url(response.url):
                try:
                    body = response.body()
                    if is_vtt_body(body):
                        captured["url"] = response.url
                        captured["body"] = body
                except Exception:
                    pass

        page.on("response", on_response)

        try:
            page.goto(video_url, wait_until="domcontentloaded", timeout=NAV_TIMEOUT_MS)
        except Exception as e:
            print(f"ERROR navegando: {e}", file=sys.stderr)
            page.close()
            return 1

        # Esperar a que cargue el reproductor
        page.wait_for_timeout(5000)

        # Abrir panel transcripcion para disparar descarga de VTT
        try_open_transcript_panel(page)

        # Esperar a que se capture
        deadline = time.time() + VTT_WAIT_MS / 1000.0
        while time.time() < deadline and not captured["body"]:
            page.wait_for_timeout(500)

        # Si aun no, intentar scroll por la transcripcion
        if not captured["body"]:
            try:
                page.mouse.wheel(0, 300)
                page.wait_for_timeout(2000)
            except Exception:
                pass

        page.close()

    if captured["body"]:
        out.write_bytes(captured["body"])
        size = len(captured["body"])
        print(f"OK VTT guardado en {out} ({size} bytes)")
        print(f"   URL origen: {captured['url'][:120]}...")
        return 0

    print(
        "FAIL No se capturo la VTT.\n"
        "     Posibles causas:\n"
        "     - Sesion SharePoint no autenticada en el Chrome CDP\n"
        "     - La grabacion no tiene transcripcion disponible\n"
        "     - El panel de transcripcion cambio de UI",
        file=sys.stderr,
    )
    return 1


def _video_extensions():
    return (".mp4", ".webm", ".m4v", ".mov", ".mkv")


def _pick_cdp_port(preferred=None):
    """Probe for an alive Chrome CDP port."""
    candidates = []
    if preferred is not None:
        candidates.append(int(preferred))
    candidates.extend([9224, 9222, 9223])
    seen = set()
    for port in candidates:
        if port in seen:
            continue
        seen.add(port)
        probe_url = "http://localhost:" + str(port) + "/json/version"
        try:
            with urllib.request.urlopen(probe_url, timeout=2) as resp:
                if "webSocketDebuggerUrl" in resp.read().decode("utf-8", errors="ignore"):
                    return port
        except Exception:
            continue
    return None


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            "Uso: python scripts/capture-vtt-cdp.py <url_video> <path_salida.vtt>",
            file=sys.stderr,
        )
        sys.exit(2)
    sys.exit(capture(sys.argv[1], sys.argv[2]))
