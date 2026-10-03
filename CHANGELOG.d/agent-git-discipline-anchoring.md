---
version_bump: patch
section: Security
---

### Security

- agent-git-discipline: las órdenes destructivas (rm, git clean/stash/reset --hard/checkout ., dd, mkfs, truncado) ya no se esquivan encadenando con && o ;, con prefijos de entorno, en subshell o con git -C; las exenciones (-i, dry-run, rutas seguras) valen solo para su propia orden; las menciones en mensajes de commit dejan de bloquear.

