---
name: /drive-sync
description: Bidirectional sync between local workspace and Google Drive
argument-hint: "[project] [push|pull|status]"
context_cost: medium
---

# /drive-sync

Sincroniza proyectos entre tu workspace local y Google Drive.

## Uso

```
/drive-sync {proyecto} push      # Subir cambios locales a Drive
/drive-sync {proyecto} pull      # Descargar cambios de Drive
/drive-sync {proyecto} status    # Mostrar estado de sincronización
```

## Argumentos

- **{proyecto}** — Nombre del proyecto (ej: sala-reservas)
- **[push|pull|status]** — Acción (por defecto: status)

## Comportamiento

**push** — Sube ficheros modificados: context/, memory/, specs/, reports/, discovery/

**pull** — Descarga Drive changes, fusiona localmente (timestamp-based, local-first)

**status** — Muestra: ficheros no sincronizados, últimas sincronizaciones, conflictos

## Ejemplos

**✅ Correcto:**
```
/drive-sync proyecto-alpha push
→ Sincronizando 3 ficheros a Drive...
  ✅ context/CLAUDE.md
  ✅ memory/decisions-2026-03.md
  ✅ reports/audit-20260305.md
Completado: 3 archivos subidos (4.2 MB)
```

## Próximo paso

- `push` → `/drive-sync {proyecto} status` para confirmar
- `pull` → revisar ficheros antes de comprometer
