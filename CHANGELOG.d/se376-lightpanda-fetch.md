---
version_bump: patch
section: Fixed
---

### Fixed

- scrapling-fetch.sh (fallback de lightpanda-browser): 4xx/5xx ya no salen como exito, bloqueo anti-SSRF (exit 3) de metadatos cloud y redes internas en cada redireccion y ante DNS rebinding (la descarga es siempre curl con la IP validada; Scrapling queda solo como parser y se pierde su bypass anti-bot), --max-bytes, decodificacion de charset, sin cuelgue con flags sin valor, sin fallo con paginas >128 KB; SKILL.md alineada con la CLI real de Lightpanda

