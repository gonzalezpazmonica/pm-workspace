---
version_bump: patch
section: Changed
---

### Changed

- **SE-343 Operator Grant — switch determinista para autonomía y merge**:
  - Nuevo `scripts/operator-grant.sh`: ledger local de grants
    (`~/.savia/grants/`, infra local, CRIT-001) con scopes `autonomy:<skill>` y
    `merge`. `grant` se emite SOLO a petición expresa de la operadora
    (`grantor` = slug activo, `source` = express-request, nunca self); `check`
    verifica vigencia; `revoke` consume.
  - `savia-double-optin-check.sh`: el factor 1 (intención previa) ahora se
    satisface con env var **o** grant `autonomy:<skill>` vigente — la operadora
    ya no necesita setear variables de entorno a mano para pedir autonomía.
  - `push-pr.sh --merge`: exige grant `merge` vigente; sin él aborta y el PR
    queda en Draft. Tras merge exitoso, el grant se consume (one-shot, TTL 6h).
  - `autonomous-safety.md`: regla de PRs pasa de "NUNCA merge" binaria a
    "merge solo con permiso expreso registrado" (SE-343).
  - `double-optin-protocol.md`: documenta las dos fuentes del factor 1.