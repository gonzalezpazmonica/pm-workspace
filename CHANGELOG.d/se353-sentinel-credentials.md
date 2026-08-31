---
version_bump: patch
section: Added
---

### Added

- SE-353 Sentinel Credential Substitution: `scripts/credential-egress.sh` cifra credenciales en `~/.savia/credential-store/` (0600, AES-256-CBC+HMAC) y las resuelve SOLO en el egress de destinos autorizados — el valor real nunca entra en el contexto del modelo. Modos store/resolve/run/status/audit; destino no autorizado o marcador no registrado → REFUSE. 13 bats tests.
