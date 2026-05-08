---
name: travel-sync
description: Sincroniza workspace bidireccional entre máquina y USB.
---

# /travel-sync — Sincronizar viaje

Sincroniza cambios entre tu máquina local y la USB de forma bidireccional.
Usa git para el workspace, timestamps para config, muestra diff antes de aplicar.

**Argumentos:** `$ARGUMENTS`

## Uso

```bash
/travel-sync /media/usb0 --direction pull
/travel-sync /media/usb0 --direction push
/travel-sync /media/usb0 --direction auto
```

## Pasos

### 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 /travel-sync — Sincronizar
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Detectar dirección de sincronización

Si no se especifica `--direction`:
```
¿Qué sincronizar?
  1) pull — traer cambios de USB a máquina
  2) push — enviar cambios de máquina a USB
  3) auto — detectar origen más reciente y sincronizar
```

Si `--direction auto`: comparar timestamps de `.claude/profiles/active-user.md`
en ambas ubicaciones y sincronizar desde la más reciente.

### 3. Mostrar cambios (diff)

```bash
bash scripts/savia-travel.sh sync "$USB_PATH" --direction "$DIR" --dry-run
```

Mostrar resumen:
```
📋 Cambios a sincronizar:

Workspace (git):
  - [main] 3 commits nuevos
  - modified: claude/rules/pm-config.local.md
  - deleted: claude/scripts/old-script.sh

Config:
  - modified: .claude/profiles/active-user.md
  - modified: .pm-workspace/update-config

🔐 Sensitive (NO mostrar contenido):
  - ~/.pm-workspace/savia-keys/ (será sincronizado cifrado)

¿Aplicar cambios? → [sí/no]
```

### 4. Ejecutar sincronización

```bash
bash scripts/savia-travel.sh sync "$USB_PATH" --direction "$DIR"
```

Monitorear:
```
📦 Sincronizando workspace...
  ✅ Git pull/push completo
🔄 Sincronizando config...
  ✅ Ficheros de config actualizados
🔐 Sincronizando keys (cifradas)...
  ✅ Keys sincronizadas
```

### 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /travel-sync — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 Dirección: {pull|push|auto}
📊 Cambios: {N} ficheros sincronizados
⏱️  Duración: ~{tiempo}s
```

## Restricciones

- Siempre mostrar diff antes de aplicar
- Nunca sobrescribir sin confirmación explícita
- Si hay conflictos en git → pedir intervención humana
- Config de máquina LOCAL tiene prioridad (no sobrescribir CLAUDE.local.md sin confirmar)
