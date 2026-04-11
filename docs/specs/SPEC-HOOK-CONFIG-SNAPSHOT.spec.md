# Spec: Hook Config Snapshot — Congelar settings.json al iniciar sesion

**Task ID:**        SPEC-HOOK-CONFIG-SNAPSHOT
**PBI padre:**      Security hardening contra hook injection mid-sesion
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: claude-code-from-source, Sticky Latches pattern)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     3h
**Estado:**         Pendiente
**Max turns:**      20
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

claude-code-from-source documenta que Claude Code original usa "Sticky Latches":
una vez se envia un beta header o feature flag, NUNCA se desactiva mid-sesion.
pm-workspace tiene 31 hooks activos en `settings.json` pero NO los congela al
iniciar sesion. Esto es un **gap de seguridad real**:

- Un agente autonomo (overnight-sprint, code-improvement-loop) puede modificar
  `settings.json` mid-sesion
- El nuevo hook se activaria en la siguiente tool call
- Vector de bypass: inyectar un hook malicioso que permite lo que el original
  bloqueaba
- Tambien afecta al cache de prompt: cambios mid-sesion invalidan prefijo

**Objetivo:** implementar snapshot inmutable de `settings.json` al iniciar
sesion. Cambios mid-sesion son detectados y bloqueados (o advertidos segun
perfil). Alineado con principio Sticky Latches.

**Criterios de Aceptacion:**
- [ ] `session-init.sh` calcula SHA256 de `settings.json` al iniciar
- [ ] Snapshot persistido en `~/.savia/session-hook-snapshot`
- [ ] Hook `validate-settings-integrity.sh` verifica en cada tool call
- [ ] Mismatch del hash -> bloquear o alertar segun perfil
- [ ] Whitelist de paths para cambios legitimos (ej: hook-profile switch)
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Snapshot al iniciar sesion

```bash
# En session-init.sh, anadir:
SETTINGS_FILE="$CLAUDE_PROJECT_DIR/.claude/settings.json"
SETTINGS_HASH=$(sha256sum "$SETTINGS_FILE" | awk '{print $1}')
echo "$SETTINGS_HASH" > "$HOME/.savia/session-hook-snapshot"
echo "$SETTINGS_FILE" >> "$HOME/.savia/session-hook-snapshot"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$HOME/.savia/session-hook-snapshot"
```

### 2.2 Verificacion en PreToolUse

Nuevo hook `.claude/hooks/validate-settings-integrity.sh` en PreToolUse:

```bash
#!/bin/bash
set -uo pipefail

SNAPSHOT_FILE="$HOME/.savia/session-hook-snapshot"
[[ ! -f "$SNAPSHOT_FILE" ]] && exit 0  # primera sesion, sin snapshot

EXPECTED_HASH=$(head -n 1 "$SNAPSHOT_FILE")
CURRENT_HASH=$(sha256sum "$CLAUDE_PROJECT_DIR/.claude/settings.json" | awk '{print $1}')

if [[ "$EXPECTED_HASH" != "$CURRENT_HASH" ]]; then
  case "$SAVIA_HOOK_PROFILE" in
    strict)
      echo "SETTINGS INTEGRITY: hash mismatch detected. Blocking." >&2
      exit 2  # block
      ;;
    standard|ci)
      echo "SETTINGS INTEGRITY: hash mismatch detected. Warning only." >&2
      exit 0  # warn, don't block
      ;;
    minimal)
      exit 0
      ;;
  esac
fi
exit 0
```

### 2.3 Whitelist de cambios legitimos

Existen casos donde cambiar `settings.json` mid-sesion es legitimo:

- `/hook-profile set X` — cambia `SAVIA_HOOK_PROFILE`
- `/update` — actualiza pm-workspace (incluyendo settings)

Estos comandos deben:

1. Detectar que van a modificar settings.json
2. Llamar a `scripts/settings-snapshot-refresh.sh` ANTES del cambio
3. El script actualiza el hash en `~/.savia/session-hook-snapshot`
4. Tras el cambio, el hash coincide y no se bloquea

### 2.4 Detalles del snapshot

```
$HOME/.savia/session-hook-snapshot
┌─────────────────────────────────────────┐
│ SHA256_HASH_DEL_SETTINGS                 │
│ /path/al/settings.json                   │
│ 2026-04-11T10:30:00Z                     │
│ /path/al/directorio/session             │
│ SAVIA_HOOK_PROFILE_INICIAL              │
└─────────────────────────────────────────┘
```

### 2.5 Comportamiento por perfil

| Perfil | Mismatch detectado | Accion |
|--------|-------------------|--------|
| strict | Bloquear tool call | Exit 2 |
| standard | Advertir, no bloquear | Exit 0 + stderr |
| ci | Advertir, no bloquear | Exit 0 + stderr |
| minimal | Ignorar | Exit 0 |

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| HCS-01 | Snapshot calculado SIEMPRE al iniciar sesion | Proteccion incompleta |
| HCS-02 | Hash verificado en cada tool call | Bypass ventana de ataque |
| HCS-03 | Cambios legitimos refrescan el snapshot | UX rota |
| HCS-04 | Cambios no documentados en strict -> bloquear | Bypass permitido |
| HCS-05 | Log de TODO mismatch en auditoria | Sin forensia |
| HCS-06 | Snapshot NUNCA se auto-regenera sin refresh script | Vector de ataque |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | sha256sum (coreutils), disponible en Linux/macOS |
| Performance | Verificacion <50ms por tool call |
| Fallback | Si el snapshot no existe, no bloquear (primera sesion) |
| Auditoria | Cada mismatch registrado en output/audits/hook-integrity.jsonl |
| Compatibilidad | Perfiles hook-profile deben coexistir (strict/standard/ci/minimal) |

---

## 5. Test Scenarios

### Primera sesion — snapshot creado

```
GIVEN   no existe ~/.savia/session-hook-snapshot
WHEN    session-init corre
THEN    snapshot creado con hash actual
AND     log "snapshot created"
```

### Sesion en curso — hash coincide

```
GIVEN   snapshot existe, settings.json sin cambios
WHEN    tool call ejecutada
THEN    hash coincide, exit 0
AND     sin warnings
```

### Mismatch en perfil strict

```
GIVEN   perfil strict, settings.json modificado mid-sesion
WHEN    tool call ejecutada
THEN    validate-settings-integrity.sh exit 2
AND     tool call bloqueada
AND     log mismatch con timestamp en auditoria
```

### Mismatch en perfil standard

```
GIVEN   perfil standard, settings.json modificado
WHEN    tool call ejecutada
THEN    exit 0 con stderr warning
AND     tool call procede
AND     log mismatch en auditoria
```

### Cambio legitimo via /hook-profile

```
GIVEN   usuario ejecuta /hook-profile set strict
WHEN    hook-profile.sh llama settings-snapshot-refresh.sh
THEN    snapshot refrescado con nuevo hash
AND     siguiente tool call no detecta mismatch
```

### Primera sesion sin snapshot (fallback)

```
GIVEN   sesion sin ~/.savia/session-hook-snapshot
WHEN    validate-settings-integrity corre
THEN    exit 0 (no bloquear)
AND     sin warnings (comportamiento idempotente)
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Modificar | .claude/hooks/session-init.sh | Calcular snapshot al iniciar |
| Crear | .claude/hooks/validate-settings-integrity.sh | Verificador en PreToolUse |
| Crear | scripts/settings-snapshot-refresh.sh | Refresh manual del snapshot |
| Modificar | scripts/hook-profile.sh | Llamar refresh tras cambio |
| Modificar | .claude/commands/update.md | Llamar refresh tras update |
| Modificar | .claude/settings.json | Registrar hook en PreToolUse |
| Crear | tests/test-hook-config-snapshot.bats | Suite BATS |
| Modificar | .claude/rules/domain/hook-profiles.md | Documentar integridad |
| Modificar | .gitignore | Excluir ~/.savia/session-hook-snapshot |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Deteccion de mismatch | 100% | Test de inyeccion simulada |
| Falsos positivos | 0 | Cambios legitimos no bloqueados |
| Latencia adicional | <50ms por tool call | Benchmark |
| Cobertura de ataques | Zero bypass mid-sesion | Red team test |

---

## Checklist Pre-Entrega

- [ ] session-init.sh calcula snapshot SHA256
- [ ] validate-settings-integrity.sh en PreToolUse
- [ ] settings-snapshot-refresh.sh funcional
- [ ] hook-profile.sh integrado con refresh
- [ ] Comportamiento diferenciado por perfil (strict/standard/ci/minimal)
- [ ] Log de auditoria de mismatches
- [ ] Test de inyeccion simulada pasa
- [ ] Tests BATS >=80 score
