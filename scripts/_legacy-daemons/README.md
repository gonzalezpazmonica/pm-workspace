# Legacy daemons — VASS only

Daemons exploratorios para una cuenta corporativa secundaria. Se conservan aquí porque pre-datan a `browser-daemon.py`.

| Script | Modo | Notas |
|---|---|---|
| `vass_persistent.py` | persistente, puerto 9221 | Inbox + Calendario; signals `~/.savia/vass-extract.signal` y `~/.savia/vass-calendar.signal` |
| `vass_ref.py` | one-shot, headless | Extracción rápida sin UI |

Output: `./output/inbox-vass-chromium.json` y `./output/cal-vass-15.json`.

**Deprecated**: usar `browser-daemon.py` (canonical) para extracciones nuevas. Se conservan como referencia histórica.
