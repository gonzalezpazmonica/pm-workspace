---
name: travel-verify
description: Verifica integridad de un paquete de viaje en USB.
---

# /travel-verify — Verificar paquete

Valida que el paquete de viaje en la USB está íntegro, todos los
checksums pasan y los datos cifrados son descifrables.

**Argumentos:** `$ARGUMENTS`

## Uso

```bash
/travel-verify /media/usb0
/travel-verify /media/usb0 --quick
```

## Pasos

### 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /travel-verify — Verificación de integridad
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Verificar estructura

```
📂 Verificando estructura...
  ✅ savia-backup.enc (50 MB)
  ✅ savia-backup.manifest
  ✅ savia-init.sh (ejecutable)
  ✅ README.travel
```

### 3. Verificar checksums (fast path si --quick)

```bash
bash scripts/savia-travel.sh verify "$USB_PATH" --checksums
```

```
📋 Verificando checksums SHA256...
  ✅ claude/ — OK
  ✅ .claude/ — OK
  ✅ .pm-workspace/ — OK
  ❌ lost-keys.tar.gz — MISMATCH (esperado: abc123..., obtenido: def456...)

🔴 1 fichero con checksum incorrecto.
   → Posible corrupción de USB
   → Recomienda: crear nuevo backup desde máquina original
```

### 4. Verificar descifrado (si pasa checksums)

```
🔐 Intentando descifrado sin contraseña (test)...
```

Si tiene éxito:
```
  ✅ Cifrado intacto — descifrado exitoso
```

Si falla:
```
  ❌ Cifrado corrupto — no se puede descifrar
```

### 5. Verificar dependencias (si --quick no especificado)

```
⚙️  Verificando dependencias para unpack...
  ✅ bash 5.1+
  ✅ git 2.34+
  ✅ openssl 3.0+
  ⚠️  node 18+ no encontrado (necesario para `npm` en workspace)
     → Recomendación: instalar antes de unpack
```

### 6. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /travel-verify — Verificación completada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Estado: 🟢 ÍNTEGRO (100%)
   Checksums: 4/4 OK
   Cifrado: descifrables
   Dependencias: {X/Y} disponibles

📌 Si hay fallos:
   → Copiar nuevo backup desde máquina original
   → No intentar usar USB con checksums fallidos
⏱️  Duración: ~{tiempo}s
```

## Restricciones

- `--quick` salta verificación de dependencias
- Nunca mostrar contenido de ficheros (solo estadísticas)
- Si hay checksums fallidos → NUNCA intentar unpack (stop)
- Checksums incorrectos = corrupción potencial (no recuperable)
