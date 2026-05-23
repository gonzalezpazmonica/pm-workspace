# Decision Trees — security-guardian

> Cap ≤80 lines. Gate pre-commit. Branching ≤4.

## Cuándo aceptar la tarea

El security-guardian acepta si:
- Hay cambios staged a punto de commit (audit pre-commit).
- Hay PR abriéndose contra repo público (audit confidencialidad).
- Hay sospecha de fuga de datos personales, credenciales o infra privada.
- Se valida cumplimiento de Rule #20 (PII-Free) o #20b (Operational Privacy).

El security-guardian **NO acepta** y delega si:
- La petición es "audita el código por vulnerabilidades sistémicas" → `security-attacker` + `security-defender`.
- La petición es "revisa compliance legal" → skill `legal-compliance`.
- La petición es "scan de CVEs en dependencias" → skill `nuclei-scanning`.

## Routing por tipo de hallazgo

| Hallazgo | Acción |
|---|---|
| **Credencial literal** (PAT, API key, password) | **BLOCK** inmediato + abort commit + pedir uso de `$ENV_FILE` |
| **PII** (email real, teléfono, nombre cliente) | **BLOCK** + sanitizar a placeholder genérico (alice, test-org) |
| **Infra privada** (IP, FQDN interno, connection string) | **BLOCK** + mover a `~/.savia/` o vault |
| **Path absoluto del usuario** en doc pública | **WARN** + sugerir variable |
| **Falso positivo razonable** | **ALLOW** + log decisión en `output/audit-decisions.jsonl` |

## Niveles de confidencialidad (N1-N4b)

| Nivel | Dónde puede ir | Quién accede |
|---|---|---|
| **N1** Public | Repo público, internet | Cualquiera |
| **N2** Empresa | Repo privado de la org | Empleados |
| **N3** Usuario | `~/.savia/` | Sólo el usuario activo |
| **N4** Proyecto | `projects/<name>/` (gitignored real) | Equipo del proyecto |
| **N4b** PM-Only | `projects/<name>/pm-only/` | Sólo la PM |

Frontera crítica: **N4/N4b → N1**. SIEMPRE bloquear.

## Composición con otros guards

- `validate-bash-global` corre antes (sanity).
- `auto-redact-credentials` corre antes (mutación si env var existe).
- `security-guardian` es el **bouncer final** — fail-closed.
- `block-credential-leak` es la capa abort-only complementaria.

## Escalado a humano

Escalar SIEMPRE si:
- Hallazgo de credencial real en historial de git (no sólo staged) → rotar credencial + BFG.
- PII de cliente identificable en >1 fichero → revisar GDPR exposure.
- Cambio en `.gitignore` que des-ignora paths con datos sensibles previos.
- Detección de blob base64 que decodifica a credencial → triage manual.

## Anti-patrones (NO hacer)

- Reportar y dejar pasar el commit — siempre BLOCK ante duda razonable.
- Sanitizar automáticamente PII sin avisar al humano (puede romper tests).
- Asumir que `*.local.md` está siempre gitignored — verificar con `git check-ignore`.
