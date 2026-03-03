---
name: travel-pack
description: Empaca tu workspace en una unidad USB con cifrado AES-256.
---

# /travel-pack — Empacar Savia en USB

Crea un paquete portátil de tu workspace, configuración y claves privadas
para llevar en una USB. Cifrado con contraseña.

**Argumentos:** `$ARGUMENTS`

## Uso

```bash
/travel-pack /media/usb0/savia-backup
```

## Pasos

### 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /travel-pack — Preparar viaje
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Requisitos previos

- ✅ Destino USB existe y tiene ≥500MB libres
- ✅ Todos los cambios están commiteados (no hay staged changes)
- ✅ PAT de Azure DevOps está guardado localmente (opcional)

Si falta algo → error explícito con solución.

### 3. Solicitar contraseña

```
🔐 Elige contraseña para el cifrado (mínimo 12 caracteres):
   → [pedir al usuario interactivamente]
   → Pedirla de nuevo para confirmar
```

### 4. Llamar a savia-travel.sh pack

```bash
bash scripts/savia-travel.sh pack "$DESTINATION" "$PASSPHRASE"
```

Monitorear progreso:
```
📦 Recopilando ficheros...
  ✅ Workspace (claude/) — 42 MB
  ✅ Config (.claude/) — 8 MB
  ✅ Perfil activo — 0.2 MB
  ✅ Keys (~/.pm-workspace/savia-keys/) — 0.1 MB

🔐 Cifrando con AES-256...
📝 Generando checksums SHA256...
✅ Creando launcher script...
```

### 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /travel-pack — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💾 Archivo: /media/usb0/savia-backup.enc (50 MB)
📋 Manifest: /media/usb0/savia-backup.manifest
🚀 Launcher: /media/usb0/savia-init.sh (cópialo a la USB)
🔐 Contraseña guardada en: ~/.pm-workspace/.travel-passphrase.enc
   (cifrada — usarla si olvidas contraseña)
⏱️  Duración: ~45s
```

## Restricciones

- Nunca solicitar contraseña dos veces en una sesión
- NO guardar contraseña en claro
- Verificar USB write-protected antes de proceder
- Si USB se desconecta: reintento automático
