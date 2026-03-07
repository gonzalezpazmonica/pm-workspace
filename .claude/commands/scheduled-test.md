---
name: scheduled-test
description: Enviar test message para verificar integración de plataforma de notificaciones
developer_type: pm
agent: task
context_cost: low
---

# /scheduled-test

> 🧪 Enviar test message para verificar que la integración funciona

---

## Argumentos

`$ARGUMENTS` = nombre de plataforma (obligatorio)

`telegram|slack|teams|whatsapp|nextcloud`

Ejemplo: `/scheduled-test slack`

---

## Flujo

1. Validar que `.env` contiene credenciales para la plataforma
2. Llamar a `scripts/notify-{platform}.sh` con mensaje de test
3. Capturar respuesta HTTP y log
4. Mostrar resultado

---

## Output

Éxito:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /scheduled-test {platform} — OK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Mensaje enviado exitosamente
   Plataforma: {platform}
   HTTP Status: {code}
   Time: {ms}ms
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Fallo:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ /scheduled-test {platform} — FALLO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ Error en envío
   Causa: {error message}
   Código: {HTTP code}

Soluciona:
1. Verifica credenciales en .env
2. Ejecuta /scheduled-setup {platform} para reconfigurar
3. Revisa logs en output/notifications/{platform}-errors.log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Timeout y Reintentos

Timeout: 10 segundos máximo. Sin reintentos automáticos (mostrar error directo).
