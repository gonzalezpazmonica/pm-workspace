---
name: travel-unpack
description: Desempaca tu workspace desde USB en una nueva máquina.
---

# /travel-unpack — Desempacar Savia

Restaura tu workspace completo desde una USB en una máquina nueva.
Detecta el OS, verifica dependencias, desencripta y configura.

**Argumentos:** `$ARGUMENTS`

## Uso

```bash
/travel-unpack /media/usb0
```

## Pasos

### 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /travel-unpack — Desempacar viaje
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Detectar OS y verificar dependencias

```
🔍 OS detectado: Ubuntu 22.04 LTS (x86_64)
✅ bash 5.1+
✅ git 2.34+
✅ openssl 3.0+
❌ node no instalado — requiere node ≥18

⚠️  Algunas dependencias faltan. ¿Instalarlas automáticamente?
   (requiere sudo) → [sí/no]
```

Si el usuario dice sí → `sudo apt-get install nodejs` (con detección auto de distro).

### 3. Solicitar contraseña

```
🔐 Contraseña del viaje (savia-init.sh solicitará contraseña):
   → [pedir interactivamente — no mostrar caracteres]
```

### 4. Llamar a savia-travel.sh unpack

```bash
bash scripts/savia-travel.sh unpack "$USB_PATH" "$PASSPHRASE"
```

Monitorear:
```
📦 Verificando archivo...
🔐 Descifrando (esto puede tardar ~10s)...
✅ Verificando checksums...
  ✅ claude/ (42 MB)
  ✅ .claude/ (8 MB)
  ✅ .pm-workspace/ (0.5 MB)

📝 Restaurando perfiles...
⚙️  Configurando symlinks...
```

### 5. Ejecutar verificación

```bash
bash scripts/savia-travel.sh verify "$USB_PATH"
```

### 6. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /travel-unpack — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Workspace restaurado: ~/claude/
🧑 Perfil activo: {nombre}
🔑 Keys configuradas: ~/.pm-workspace/savia-keys/
✅ Verificación: 100% integridad

⚡ Próximo paso: /context-load
   (cargar contexto de tu workspace)
⏱️  Duración: ~1m
```

## Restricciones

- Pedir confirmación explícita antes de sobrescribir perfil existente
- Nunca instalar dependencias sin permiso (`sudo` requiere interacción)
- Si falla descifrado → pedir contraseña de nuevo (máx 3 intentos)
- Verificar integridad ANTES de restaurar (no sobrescribir datos rotos)
