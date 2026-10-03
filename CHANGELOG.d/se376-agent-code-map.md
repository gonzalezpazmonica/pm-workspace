---
version_bump: patch
section: Fixed
---

### Fixed

- agent-code-map: refresh-agent-maps.sh emite JSON válido (escapado de barras, comillas y controles; asunto truncado por git respetando UTF-8), no marca stale-no-checkout un checkout con una sola entrada, no pisa las citas del cuerpo del .acm, reporta missing-acm y missing-repo con exit 1, rechaza slug/repo con path traversal (exit 2) y escribe con temporal único seguro en concurrencia. SKILL.md alineado: los comandos /codemap:* no existen.

