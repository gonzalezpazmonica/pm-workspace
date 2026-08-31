# SE-353 — Sentinel Secret Substitution: credenciales fuera del contexto del modelo

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Seguridad / Secrets
**Fuente de inspiración:** OpenClaw 2.0 (SecretRefs + egress sentinels, protected store)
**Criterio humano aplicable:** CRIT-001 (infraestructura propia, sin proveedor cloud)

---

## Objetivo

Garantizar que el **valor real de las credenciales jamás entre en el contexto
del modelo**. Sustituir el valor del PAT y otros secretos por un **sentinel**
opaco que solo se resuelve en el punto de egress (destino autorizado). Un
sentinel malformado o no reconocido es **rechazado** en el egress, no reenviado.

## Contexto

Savia cumple Rule #1 (NUNCA hardcodear PAT; siempre `$(cat $PAT_FILE)`), pero
el **valor del PAT sí aparece en el prompt del modelo** cuando un script lo
interpola. OpenClaw resuelve esto con: (1) SecretRefs en la configuración, (2)
**protected store** cuyos valores se omiten de lecturas del agente, y (3)
**sentinels** sustituidos solo en el egress del destino autorizado. El threat
model es: si el agente (o un prompt-injection) ve el sentinel cifrado, no
obtiene el secreto.

**Rechazo explícito (CRIT-001):** no se adopta ningún vault cloud. La tienda
protegida es local (`~/.savia/secrets/`), cifrada con clave de archivo, mismo
principio que `pm-config.local.md` gitignored.

## Diseño

### 1. Formato sentinel

`SAVIA_SECRET_<KEY>` con valor `savias:enc:<base64-opaco>` — nunca el valor
real. Ejemplo: `AZURE_PAT=savias:enc:a3f8...`.

### 2. Resolución en egress

`scripts/secret-egress.sh` (nuevo):
- Entrada: comando + args que contienen sentinels
- Si el destino del comando está en la allowlist (ADo, GitHub) → sustituye sentinel por valor real en el **subproceso hijo**, no en el contexto del padre
- Si el sentinel no está registrado o el destino no está autorizado → **REFUSE** (exit non-zero)

### 3. Tienda protegida

`~/.savia/secrets/keys.json` (0600): `{key: {value_cipher: ..., hmac: ...}}`.
`secrets` subcomandos: `store`, `resolve`, `status`, `audit`.

### 4. Migración

`scripts/secret-migrate.sh` detecta interpolaciones `$(cat $PAT_FILE)` y las
reemplaza por `$SAVIA_SECRET_...` (dry-run primero). `secrets audit` reporta
plaintext en repos/config.

## Criterios de aceptación

- **AC-0** `secret-egress.sh` sustituye sentinel por valor en hijo, sin exponerlo en stdout del padre
- **AC-1** Sentinel no registrado → REFUSE (exit != 0), nunca reenvío
- **AC-2** Destino no autorizado → REFUSE
- **AC-3** `secrets audit` detecta PAT en texto plano en scripts/config (dataset sintético)
- **AC-4** `secret-migrate.sh --dry-run` reporta sin modificar; `--apply` migra y deja backup
- **AC-5** Sin regresión: push-pr.sh y scripts que usan `$PAT_FILE` siguen funcionando contra ADo (e2e local mock)
- **AC-6** Tienda con permisos 0600 verificados por test

## OpenCode Implementation Plan

### Bindings touched
- `scripts/secret-egress.sh` (nuevo), `scripts/secret-migrate.sh` (nuevo)
- `scripts/push-pr.sh`, `scripts/ado-*.sh`, `scripts/git-*.sh` (sustitución de interpolación)
- `docs/rules/domain/critical-rules-extended.md` (Rule #1 update)

### Verification protocol
```bash
bats tests/bats/test-secret-egress.bats
bats tests/bats/test-secret-audit.bats
bash scripts/secret-egress.sh --self-check
```

### Portability classification
- Bash + openssl/python3 stdlib → portable a todos los frontends
- No depende de infraestructura externa

## Trabajo futuro (fuera de scope)
- Rotación automática de PAT — spec independiente
- Vault integración (1Password) — opcional, no requerido

## Referencias
- OpenClaw: `docs/start/why-openclaw.md` (Secrets: SecretRefs, sentinels, egress)
- Savia: Rule #1 (critical-rules-extended.md), `pm-config.local.md`, CRIT-001
- `autonomous-safety.md`
