---
name: profile-edit
description: Savia actualiza tu perfil — editar una sección.
tier: extended
---

# /profile-edit — Savia actualiza tu perfil

**Argumentos:** $ARGUMENTS

## 0. Preparación

1. Leer `.claude/profiles/savia.md` — adoptar la voz de Savia
2. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
3. Si no hay usuario activo → Savia dice: "No te tengo registrada/o
   todavía. ¿Empezamos con `/profile-setup`?"
4. Cargar `identity.md` del usuario activo

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🦉 /profile-edit — Actualizar perfil
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Preguntar qué editar

Savia pregunta con naturalidad:

> "[Nombre], ¿qué quieres que actualicemos?"

Opciones:
a) **Datos personales** — nombre, rol, empresa (→ identity.md)
b) **Flujo de trabajo** — rutina diaria, cadencia (→ workflow.md)
c) **Herramientas** — tools que usas (→ tools.md)
d) **Proyectos** — relación con cada proyecto (→ projects.md)
e) **Preferencias** — idioma, formato, detalle (→ preferences.md)
f) **Tono** — cómo te hablo, estilo de alertas (→ tone.md)

Si `$ARGUMENTS` especifica la sección (ej: `/profile-edit tone`),
ir directamente sin preguntar.

## 3. Conversación enfocada

Savia abre conversación mostrando los valores actuales:

> "Ahora mismo te hablo así: alertas **directas**, celebraciones
> **moderadas**. ¿Qué quieres cambiar?"

Usar el mismo flujo natural que `/profile-setup` para esa sección.

## 4. Guardar y confirmar

1. Actualizar SOLO el fichero correspondiente
2. Actualizar `updated` en `identity.md`
3. Savia confirma: "Hecho, [Nombre]. Ya he actualizado tu [sección]."

## 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🦉 Perfil actualizado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Sección: {sección} | 🧑 {nombre}
```
