---
name: travel-clean
description: Elimina rastros de Savia de una máquina temporal.
---

# /travel-clean — Limpiar máquina

Elimina todos los rastros de tu workspace de una máquina temporal.
Limpia configuración, symlinks, claves y historial de bash.

**Argumentos:** `$ARGUMENTS`

## Uso

```bash
/travel-clean
/travel-clean --keep-workspace
```

## Pasos

### 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧹 /travel-clean — Limpiar máquina
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Verificar que hay que limpiar

```
🔍 Buscando rastros de Savia...
  ✅ ~/.claude/ existe (8 MB)
  ✅ ~/.pm-workspace/ existe (0.5 MB)
  ⏭️  ~/claude/ (workspace — se borrará por defecto)
  ✅ .bash_history contiene comandos claude

¿Continuar con limpieza? → [sí/no]
```

Si `--keep-workspace`: skip borrado de `~/claude/`.

### 3. Llamar a savia-travel.sh clean

```bash
bash scripts/savia-travel.sh clean [$OPTIONS]
```

Monitorear:
```
🧹 Limpiando configuración...
  ✅ ~/.claude/ eliminado (8 MB liberados)
  ✅ ~/.pm-workspace/ eliminado (0.5 MB liberados)
  ✅ Symlinks de workspace eliminados

🔐 Limpiando claves...
  ✅ ~/.pm-workspace/savia-keys/ eliminado

📝 Limpiando historial...
  ✅ Historial bash limpiado (sin comandos claude)
  ✅ Cache de búsqueda eliminado
```

### 4. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /travel-clean — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧹 Limpieza: 100%
   Espacio liberado: ~9 MB
   Elementos eliminados: 3
   Historial limpiado: ✅

⚠️  Si has dejado datos personales:
   → Revisar /tmp y ~/Downloads
   → Vaciar papelera: rm -rf ~/.Trash/*

ℹ️  Savia se fue. Hasta el próximo viaje.
⏱️  Duración: ~5s
```

## Restricciones

- Pedir confirmación explícita antes de borrar
- NO borrar `/tmp` (puede afectar otros usuarios)
- NO borrar `~/` (solo `.claude/`, `.pm-workspace/`, workspace symlinks)
- Si hay archivos modificados en workspace → avisar antes de borrar
- Preservar `.bash_history` pero limpiar solo comandos `claude` / `/` (no tocar otros)
