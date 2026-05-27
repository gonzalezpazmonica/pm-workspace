# SE-149 — Hashline edits (safe anchor-based file editing)

**Status:** APPROVED
**Fecha:** 2026-05-27
**Área:** Agent tooling / Edit safety
**Spike commit:** `388ee9ed` — `spike/SE-149-hashline-edits`

---

## Objetivo

Proveer a los agentes L3 un mecanismo de edición de ficheros basado en
anclas de hash que detecte drift de contenido antes de aplicar cambios,
reduciendo edits destructivos por contexto obsoleto.

---

## Mecanismo

1. El agente genera un **anchor** SHA-256 sobre un bloque de N líneas alrededor
   del punto de edición (`hashline-guard.sh anchor`).
2. Antes de editar, verifica que el anchor sigue siendo válido en el fichero
   actual (`hashline-guard.sh check` → exit 0 ok / 1 mismatch / 2 not-found).
3. Si el check pasa, aplica la edición con log auditado (`hashline-edit.sh`).
4. Si falla, aborta y reporta el conflicto para resolución humana.

---

## Scripts

### `scripts/hashline-guard.sh`

```
hashline-guard.sh anchor  FILE LINE [window=3]  → imprime anchor string
hashline-guard.sh check   FILE ANCHOR           → exit 0|1|2
```

- Exit 0: anchor válido, edición segura.
- Exit 1: contenido cambió desde que se generó el anchor.
- Exit 2: anchor no encontrado en el fichero.

### `scripts/hashline-edit.sh`

```
hashline-edit.sh  FILE ANCHOR OLD_STRING NEW_STRING [--dry-run]
```

Wrapper que: (1) verifica anchor, (2) aplica la sustitución exacta,
(3) escribe entrada en `$AGENT_LOGS_DIR/hashline-edits.log`.

---

## Protocolo para agentes L3

Documentado en `docs/rules/domain/hashline-edit-protocol.md`:

1. Antes de planificar cualquier edición en un fichero que otro agente puede
   estar modificando, generar anchor sobre las líneas target.
2. Pasar el anchor como parte del plan de edición.
3. En el momento de ejecutar la edición, llamar `hashline-edit.sh`.
4. Si exit ≠ 0: registrar conflicto en `agent-notes` y delegar al humano.
5. NUNCA reintentar la edición con un anchor obsoleto.

---

## Acceptance Criteria

- AC-1: `hashline-guard.sh anchor` produce un string determinista para el mismo
  bloque de contenido.
- AC-2: `hashline-guard.sh check` devuelve exit 0 si el fichero no ha cambiado.
- AC-3: `hashline-guard.sh check` devuelve exit 1 si el bloque ha sido editado
  desde que se generó el anchor.
- AC-4: `hashline-edit.sh` aplica la sustitución solo si el anchor es válido.
- AC-5: `hashline-edit.sh --dry-run` no modifica el fichero.
- AC-6: `hashline-edit.sh` escribe entrada de log con timestamp, fichero, anchor
  y resultado.
- AC-7: El protocolo `hashline-edit-protocol.md` existe y describe los 5 pasos.
- AC-8: Suite BATS ≥ 10 tests passing (estado spike: 10/10).

---

## Known Limitations (documentadas en spike)

1. **Sin protección ante race condition genuina**: el check y la edición no son
   atómicos; una modificación concurrente entre ambos pasos no se detecta.
2. **Anchor window de 3 líneas puede ser insuficiente**: si `old_string` es
   largo y ocupa más de 3 líneas, el anchor puede coincidir con otra zona del
   fichero, produciendo falso positivo.
3. **No integrado con `Edit` tool nativo**: la herramienta `Edit` de Claude no
   llama a `hashline-guard.sh` automáticamente; el agente debe invocarla
   explícitamente — Slice 2 lo resuelve con un PreToolUse hook.
4. **Sin soporte multi-fichero atómico**: si una edición lógica abarca dos
   ficheros, cada uno se verifica y edita por separado sin transacción.

---

## OpenCode Implementation Plan

```yaml
spec: SE-149
type: agent-tooling
risk: MEDIUM  # toca protocolo de agentes L3; cambio de comportamiento

slices:
  - id: S1
    name: scripts-and-protocol
    files:
      - scripts/hashline-guard.sh
      - scripts/hashline-edit.sh
      - docs/rules/domain/hashline-edit-protocol.md
      - tests/bats/SE-149-hashline-edits.bats
    ac: [AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8]
    effort: done (spike)
    action: Merge spike/SE-149-hashline-edits → main via PR.

  - id: S2
    name: pretooluse-hook
    status: FUTURE
    description: >
      Hook PreToolUse que intercepta llamadas a la herramienta Edit,
      genera anchor automáticamente y llama a hashline-guard.sh check
      antes de permitir la edición. Requiere SPEC separado.
    depends: [S1]
    ac: []
    effort: estimado 4h
```

---

## Referencias

- `docs/rules/domain/autonomous-safety.md` → agentes L3, permisos de escritura
- `docs/agent-notes-protocol.md` → cómo registrar conflictos de edición
