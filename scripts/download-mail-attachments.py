#!/usr/bin/env python3
"""Descarga los adjuntos de un correo concreto de Outlook OWA.

Reusa la session_dir del browser-daemon (cookies persistidas) — si la sesion
sigue valida, no requiere re-auth.

Uso:
    python scripts/download-mail-attachments.py \
        --account account1 \
        --subject "LYRA_Launching LYRA Short Guides" \
        --dest "$HOME/.savia/mail-attachments/lyra" \
        [--headless]

Salida JSON en stdout:
    {
      "status": "ok" | "session_expired" | "email_not_found" | "no_attachments" | "error",
      "email": "<subject visto>",
      "downloaded": [{"name": "...", "path": "...", "size": N}],
      "errors": [...],
      "screenshots": ["path/to/...png", ...]
    }

Diseno:
    - Si el daemon esta vivo, NO podemos abrir otra persistent_context apuntando
      al mismo session_dir (lock). En ese caso, intentamos connect_over_cdp al
      puerto del daemon. Si no esta vivo, launch_persistent_context reutiliza
      las cookies.
    - La busqueda usa el search box nativo de OWA, filtra por asunto y abre
      el primer match.
    - Cada adjunto se descarga via `expect_download` tras click en el boton
      "Descargar" del tile del adjunto. Si hay "Descargar todo", prioriza esa
      via.

Tolerante a idioma ES/EN (labels aria "Descargar" / "Download").
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

os.environ.setdefault("PYTHONUTF8", "1")
os.environ.setdefault("PYTHONIOENCODING", "utf-8")

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from browser_helpers import load_account, SIGNAL, DEFAULT_CDP_PORTS  # noqa: E402


def slugify_filename(name: str) -> str:
    """Limpia caracteres problematicos preservando extension."""
    name = name.strip()
    name = re.sub(r"[\\/:*?\"<>|\r\n\t]+", "_", name)
    name = re.sub(r"\s+", " ", name)
    return name[:200]


def resolve_cdp_port(alias: str, cfg: dict) -> int:
    if "cdp_port" in cfg:
        return int(cfg["cdp_port"])
    return DEFAULT_CDP_PORTS.get(alias, 0)


def screenshot(page, out_dir: Path, label: str) -> str:
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%H%M%S")
    path = out_dir / f"{ts}-{label}.png"
    try:
        page.screenshot(path=str(path), full_page=False)
        return str(path)
    except Exception:
        return ""


def try_connect_cdp(playwright_ctx, alias: str, cfg: dict):
    """Intenta conectar al daemon via CDP. None si no esta vivo."""
    port = resolve_cdp_port(alias, cfg)
    if not port:
        return None
    try:
        browser = playwright_ctx.chromium.connect_over_cdp(
            f"http://127.0.0.1:{port}", timeout=3000
        )
        if not browser.contexts:
            return None
        return browser
    except Exception:
        return None


def launch_persistent(playwright_ctx, alias: str, cfg: dict, headless: bool):
    """Arranca Chromium con la session_dir del daemon (requiere daemon off)."""
    session_dir = str(SIGNAL.parent / cfg["session_dir"])
    args = [
        "--window-position=-3000,-3000",
        "--window-size=1400,900",
        "--disable-blink-features=AutomationControlled",
    ]
    ctx = playwright_ctx.chromium.launch_persistent_context(
        session_dir,
        headless=headless,
        args=args,
        viewport={"width": 1400, "height": 900},
        accept_downloads=True,
        timeout=60000,
    )
    return ctx


def find_search_box(page):
    """Localizador robusto del search box de OWA."""
    selectors = [
        'input[aria-label*="Buscar"]',
        'input[aria-label*="Search"]',
        'input[placeholder*="Buscar"]',
        'input[placeholder*="Search"]',
        'input[type="search"]',
        '[role="search"] input',
    ]
    for sel in selectors:
        loc = page.locator(sel).first
        try:
            loc.wait_for(state="visible", timeout=3000)
            return loc
        except Exception:
            continue
    return None


def open_first_email(page, subject_contains: str, log: list) -> bool:
    """Abre el primer email cuyo asunto contenga el texto."""
    # Tras la busqueda, los resultados aparecen como [role="option"] o
    # [draggable="true"] en la lista de mensajes.
    lower = subject_contains.lower()
    for _ in range(30):
        # Probar rows con el asunto
        options = page.locator('[role="option"]').all()
        for opt in options:
            try:
                txt = (opt.text_content() or "").lower()
            except Exception:
                txt = ""
            if lower in txt:
                try:
                    opt.scroll_into_view_if_needed(timeout=3000)
                    opt.click(timeout=5000)
                    log.append(f"clicked role=option '{txt[:80]}'")
                    return True
                except Exception as e:
                    log.append(f"click role=option err: {str(e)[:120]}")
        drags = page.locator('[draggable="true"]').all()
        for d in drags:
            try:
                txt = (d.text_content() or "").lower()
            except Exception:
                txt = ""
            if lower in txt:
                try:
                    d.scroll_into_view_if_needed(timeout=3000)
                    d.click(timeout=5000)
                    log.append(f"clicked draggable '{txt[:80]}'")
                    return True
                except Exception as e:
                    log.append(f"click draggable err: {str(e)[:120]}")
        page.wait_for_timeout(1000)
    return False


ATTACH_DOWNLOAD_LABELS = [
    "Descargar", "Download", "Descargar datos adjuntos", "Download attachment",
]

ATTACH_MORE_LABELS = [
    "Más opciones", "Mas opciones", "More options", "Más acciones", "Mas acciones",
]


def collect_attachment_download_buttons(page):
    """Devuelve locators de botones de descarga visibles en el panel del email."""
    seen = set()
    results = []
    for label in ATTACH_DOWNLOAD_LABELS:
        # Labels exactos y contiene
        for sel in (
            f'button[aria-label="{label}"]',
            f'button[aria-label^="{label}"]',
            f'[role="menuitem"][aria-label*="{label}"]',
            f'button[title="{label}"]',
            f'a[aria-label*="{label}"]',
        ):
            try:
                for el in page.locator(sel).all():
                    try:
                        box = el.bounding_box()
                    except Exception:
                        box = None
                    if not box:
                        continue
                    key = (round(box["x"]), round(box["y"]), sel)
                    if key in seen:
                        continue
                    seen.add(key)
                    results.append(el)
            except Exception:
                continue
    return results


def trigger_download_all(page, log: list) -> list:
    """Intenta clickar 'Descargar todo' si existe. Devuelve lista de downloads."""
    labels = ["Descargar todo", "Descargar todos", "Download all"]
    for lbl in labels:
        btn = page.locator(f'button[aria-label*="{lbl}"], button:has-text("{lbl}")').first
        try:
            btn.wait_for(state="visible", timeout=2000)
        except Exception:
            continue
        try:
            with page.expect_download(timeout=45000) as dl_info:
                btn.click(timeout=5000)
            dl = dl_info.value
            log.append(f"download-all triggered via '{lbl}'")
            return [dl]
        except Exception as e:
            log.append(f"download-all '{lbl}' err: {str(e)[:120]}")
    return []


def download_each_attachment(page, log: list) -> list:
    """Itera botones de Descargar individuales y captura cada fichero."""
    downloads = []
    # Buscar tiles de adjuntos para hover/click
    attach_tiles = page.locator(
        '[data-testid*="attachment"], [aria-label*="Datos adjuntos"], '
        '[aria-label*="Attachment"], [role="button"][aria-label*=".pdf"], '
        '[role="button"][aria-label*=".docx"], [role="button"][aria-label*=".pptx"], '
        '[role="button"][aria-label*=".xlsx"]'
    ).all()
    log.append(f"attachment_tiles_found={len(attach_tiles)}")

    # Primero intentamos con botones "Descargar" directos
    buttons = collect_attachment_download_buttons(page)
    log.append(f"direct_download_buttons={len(buttons)}")

    if buttons:
        for i, btn in enumerate(buttons):
            try:
                btn.scroll_into_view_if_needed(timeout=3000)
            except Exception:
                pass
            try:
                with page.expect_download(timeout=45000) as dl_info:
                    btn.click(timeout=5000)
                dl = dl_info.value
                downloads.append(dl)
                log.append(f"download #{i+1} triggered")
                page.wait_for_timeout(1500)
            except Exception as e:
                log.append(f"download #{i+1} err: {str(e)[:160]}")
        return downloads

    # Fallback: por cada tile, abrir menu "Más opciones" > "Descargar"
    for i, tile in enumerate(attach_tiles):
        try:
            tile.scroll_into_view_if_needed(timeout=3000)
            tile.hover(timeout=3000)
        except Exception:
            pass
        # Menu contextual del tile
        menu_btn = None
        for m_label in ATTACH_MORE_LABELS:
            try:
                candidate = tile.locator(
                    f'button[aria-label*="{m_label}"]'
                ).first
                candidate.wait_for(state="visible", timeout=1500)
                menu_btn = candidate
                break
            except Exception:
                continue
        if not menu_btn:
            log.append(f"tile #{i+1}: no menu button")
            continue
        try:
            menu_btn.click(timeout=3000)
            page.wait_for_timeout(800)
        except Exception as e:
            log.append(f"tile #{i+1} menu click err: {str(e)[:120]}")
            continue
        # Buscar item "Descargar" en el menu abierto
        dl_item = None
        for lbl in ATTACH_DOWNLOAD_LABELS:
            try:
                cand = page.locator(
                    f'[role="menuitem"]:has-text("{lbl}")'
                ).first
                cand.wait_for(state="visible", timeout=2500)
                dl_item = cand
                break
            except Exception:
                continue
        if not dl_item:
            log.append(f"tile #{i+1}: no download menuitem")
            page.keyboard.press("Escape")
            continue
        try:
            with page.expect_download(timeout=45000) as dl_info:
                dl_item.click(timeout=5000)
            dl = dl_info.value
            downloads.append(dl)
            log.append(f"tile #{i+1}: downloaded")
            page.wait_for_timeout(1200)
        except Exception as e:
            log.append(f"tile #{i+1} download err: {str(e)[:160]}")
    return downloads


def run(alias: str, subject: str, dest: Path, headless: bool, debug_dir: Path):
    from playwright.sync_api import sync_playwright

    dest.mkdir(parents=True, exist_ok=True)
    debug_dir.mkdir(parents=True, exist_ok=True)

    log = []
    result = {
        "status": "unknown",
        "account": alias,
        "subject_query": subject,
        "downloaded": [],
        "errors": [],
        "log": log,
        "screenshots": [],
    }
    cfg = load_account(alias)

    with sync_playwright() as pw:
        ctx = None
        browser = None
        connected_mode = None
        # Priority 1: CDP to living daemon
        browser = try_connect_cdp(pw, alias, cfg)
        if browser and browser.contexts:
            ctx = browser.contexts[0]
            connected_mode = "cdp"
            log.append("connected via CDP")
        else:
            log.append("CDP unavailable, launching persistent context")
            try:
                ctx = launch_persistent(pw, alias, cfg, headless=headless)
                connected_mode = "persistent"
            except Exception as e:
                result["status"] = "error"
                result["errors"].append(f"launch failed: {str(e)[:200]}")
                print(json.dumps(result, ensure_ascii=False, indent=2))
                return 2

        try:
            page = ctx.pages[0] if ctx.pages else ctx.new_page()
            # Prepare download dir hint for Chromium (only for persistent mode)
            try:
                page.set_viewport_size({"width": 1400, "height": 900})
            except Exception:
                pass

            page.goto(cfg.get(
                "mail_url", "https://outlook.office365.com/mail/inbox"
            ), wait_until="domcontentloaded", timeout=60000)
            page.wait_for_timeout(7000)

            if "login" in page.url or "sso." in page.url:
                result["status"] = "session_expired"
                result["screenshots"].append(
                    screenshot(page, debug_dir, "session-expired")
                )
                print(json.dumps(result, ensure_ascii=False, indent=2))
                return 3

            result["screenshots"].append(
                screenshot(page, debug_dir, "inbox")
            )

            search = find_search_box(page)
            if not search:
                result["status"] = "error"
                result["errors"].append("search box not found")
                result["screenshots"].append(
                    screenshot(page, debug_dir, "no-search")
                )
                print(json.dumps(result, ensure_ascii=False, indent=2))
                return 4
            try:
                search.click()
                search.fill(subject)
                page.keyboard.press("Enter")
            except Exception as e:
                result["errors"].append(f"search err: {str(e)[:160]}")
            page.wait_for_timeout(5000)
            result["screenshots"].append(
                screenshot(page, debug_dir, "after-search")
            )

            if not open_first_email(page, subject, log):
                result["status"] = "email_not_found"
                result["screenshots"].append(
                    screenshot(page, debug_dir, "no-email-match")
                )
                print(json.dumps(result, ensure_ascii=False, indent=2))
                return 5
            page.wait_for_timeout(5000)
            result["screenshots"].append(
                screenshot(page, debug_dir, "email-open")
            )

            # Captura asunto real del mail abierto
            try:
                h = page.locator('h1, [role="heading"][aria-level="1"], [role="heading"][aria-level="2"]').first
                h.wait_for(state="visible", timeout=3000)
                result["subject_seen"] = (h.text_content() or "").strip()[:240]
            except Exception:
                pass

            # Intentar "Descargar todo" primero
            all_downloads = trigger_download_all(page, log)
            if not all_downloads:
                all_downloads = download_each_attachment(page, log)

            if not all_downloads:
                result["status"] = "no_attachments"
                result["screenshots"].append(
                    screenshot(page, debug_dir, "no-attachments")
                )
                print(json.dumps(result, ensure_ascii=False, indent=2))
                return 6

            for dl in all_downloads:
                try:
                    suggested = dl.suggested_filename or "attachment.bin"
                    target = dest / slugify_filename(suggested)
                    # Si existe, sufijo numerico
                    if target.exists():
                        stem, ext = os.path.splitext(target.name)
                        n = 1
                        while (dest / f"{stem}.{n}{ext}").exists():
                            n += 1
                        target = dest / f"{stem}.{n}{ext}"
                    dl.save_as(str(target))
                    size = target.stat().st_size if target.exists() else 0
                    result["downloaded"].append({
                        "name": suggested,
                        "path": str(target),
                        "size": size,
                    })
                except Exception as e:
                    result["errors"].append(f"save err: {str(e)[:160]}")

            result["status"] = "ok"
            result["screenshots"].append(
                screenshot(page, debug_dir, "done")
            )
        finally:
            if connected_mode == "persistent" and ctx is not None:
                try:
                    ctx.close()
                except Exception:
                    pass
            # En CDP no cerramos el context (es del daemon externo)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "ok" else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--account", required=True)
    ap.add_argument("--subject", required=True,
                    help="Texto contenido en el asunto (case-insensitive)")
    ap.add_argument("--dest", required=True)
    ap.add_argument("--headless", action="store_true", default=True)
    ap.add_argument("--no-headless", dest="headless", action="store_false")
    ap.add_argument("--debug-dir", default=str(
        Path.home() / ".savia" / "mail-download-debug"
    ))
    args = ap.parse_args()
    sys.exit(run(
        args.account,
        args.subject,
        Path(args.dest),
        headless=args.headless,
        debug_dir=Path(args.debug_dir),
    ))


if __name__ == "__main__":
    main()
