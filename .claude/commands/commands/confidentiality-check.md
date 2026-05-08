---
name: confidentiality-check
description: "Auditoria pre-PR de confidencialidad y firma criptografica"
---

# /confidentiality-check — Auditoria pre-PR de confidencialidad + firma

> Lanza el agente confidentiality-auditor para auditar el diff del PR actual.
> Si pasa, genera firma criptografica para la pipeline de CI.
> Regla: @docs/rules/domain/context-placement-confirmation.md

---
name: confidentiality-check

## Parametros

- `$ARGUMENTS` — (opcional) `--sign-only` para firmar sin re-auditar

## Flujo

### Paso 1 — Lanzar agente auditor (subagent)

Delegar al agente `confidentiality-auditor` con este prompt:

> Audita el diff del PR actual para pm-workspace (repo publico).
>
> 1. Lee las fuentes de contexto sensible del workspace:
>    - `projects/` (listar directorios para nombres reales de proyecto)
>    - `CLAUDE.local.md` (orgs, proyectos, URLs)
>    - `.claude/profiles/users/*/identity.md` (nombres de personas)
>    - `.claude/rules/pm-config.local.md` (config real)
>    - `projects/*/team/TEAM.md` (miembros del equipo)
> 2. Construye diccionario de datos sensibles con variantes
> 3. Obtiene el diff: `git diff origin/main...HEAD`
> 4. Audita CADA linea anadida buscando filtraciones
> 5. Emite veredicto CLEAN o BLOCKED con hallazgos

### Paso 2 — Procesar veredicto

Si BLOCKED:
- Mostrar hallazgos criticos con fichero y linea
- NO generar firma
- Sugerir correcciones

Si CLEAN:
- Ejecutar `bash scripts/confidentiality-sign.sh sign`
- Informar que se debe commitear `.confidentiality-signature`

### Paso 3 — Scan determinista (defensa en profundidad)

Ejecutar tambien: `bash scripts/confidentiality-scan.sh --pr`
Si el scan detecta algo que el agente no vio → BLOCKED.

## Banner de finalizacion

```
/confidentiality-check — Completado
Veredicto: CLEAN / BLOCKED
Firma: generada / no generada
Siguiente: git add .confidentiality-signature && git commit
/compact
```
