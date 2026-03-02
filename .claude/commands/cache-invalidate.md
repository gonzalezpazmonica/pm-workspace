---
name: cache-invalidate
description: Invalidación selectiva de capas de caché con rollback seguro
developer_type: all
agent: none
context_cost: high
---

# /cache-invalidate

> 🦉 Savia invalida solo la capa que cambió — fino, no brusco.

---

## Cargar perfil de usuario

Grupo: **Context Engineering** — cargar:

- `workflow.md` — para validar impacto de invalidación

Ver `.claude/rules/domain/context-map.md`.

---

## Parámetros

```
--layer tools|system|rag|conversation    Capa a invalidar (por defecto: todas)
--selective                               Invalidación granular vs. full flush
--lang es|en                              Idioma del output
```

---

## Flujo

### Paso 1 — Verificar caché actual

1. Leer estado del caché: `$HOME/.pm-workspace/cache-state.json`
2. Mostrar: tamaño total, por capa, timestamp creación, edad fragmentos

### Paso 2 — Detectar cambios (para --selective)

Si `--selective`: detectar qué cambió en `.git/index`:
- Tools: cambios `.claude/rules/` → invalidar TOOLS
- System: cambios CLAUDE.md → invalidar SYSTEM
- RAG: cambios `docs/` → invalidar RAG
- Conversation: comandos ejecutados → invalidar CONVERSATION

### Paso 3 — Proponer invalidación

**Sin --layer** (auto):
```
🔄 Invalidación Automática

Layers afectadas:
├─ ✅ TOOLS (cambios reglas)      → Invalidar
├─ ✅ SYSTEM (cambios CLAUDE.md)  → Invalidar
├─ ✅ RAG (cambios docs)          → Invalidar
└─ ⏸️ CONVERSATION (en sesión)    → Mantener

¿Proceder? (y/n)
```

### Paso 4 — Crear backup pre-invalidación

1. Guardar snapshot: `$HOME/.pm-workspace/cache-backups/cache-{timestamp}.json.bak`
2. Registrar qué se invalidó
3. Mostrar ruta del backup

### Paso 5 — Ejecutar invalidación

**Granular (--selective)**:
- Marcar fragmentos como "stale" en `cache-state.json`
- No borrar — dejar que expiren según TTL
- Cuando se acceda → recargar

**Full flush** (sin --selective):
- Borrar layer completa
- Próximo comando → recarga completa

Mostrar:
```
✅ Invalidación Completada

Layer TOOLS: 45 ficheros invalidados
Layer SYSTEM: 1 fichero invalidado
Layer RAG: 12 ficheros invalidados

Impacto: próximos comandos +3s latencia
```

### Paso 6 — Registrar rollback

Si el usuario se arrepiente (misma sesión):
```
⏮️ Rollback disponible

Backup: $HOME/.pm-workspace/cache-backups/cache-{timestamp}.json.bak

¿Restaurar? (y/n)
```

---

## Validación

- ✅ Layer válida (tools|system|rag|conversation|all)
- ✅ Backup creado antes de invalidar
- ✅ Cambios detectados correctamente (--selective)
- ✅ TTLs respetados (no forzar si aún válido)

---

## Restricciones

- NUNCA invalidar sin backup
- Rollback solo disponible en misma sesión (30 min)
- Sistema NUNCA borra datos — solo marca "stale"

