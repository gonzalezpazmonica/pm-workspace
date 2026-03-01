---
name: feedback
description: Abrir incidencias, ideas o mejoras como issues en el repositorio de pm-workspace
developer_type: all
agent: none
context_cost: low
---

# /feedback {subcommand}

> 🦉 ¿Algo no funciona o se te ocurre una mejora? Savia lo reporta por ti.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar `identity.md` del perfil activo.
Ver `.claude/profiles/context-map.md`.

## Prerequisitos

- `gh` CLI instalado y autenticado
- Leer `@.claude/rules/domain/community-protocol.md` para guardrails de privacidad

## Subcomandos

### `/feedback bug "descripción"`

Reportar un bug:

1. Mostrar banner: `🦉 Feedback · Bug`
2. Verificar prerequisitos — mostrar ✅/❌
3. Pedir pasos para reproducir si el usuario no los ha dado
4. Validar privacidad: `bash scripts/contribute.sh validate "contenido"`
5. Confirmar con el usuario
6. `bash scripts/contribute.sh issue "Bug: descripción" "cuerpo" "bug,community"`
7. Mostrar URL del issue creado
8. Banner fin: `✅ Bug reportado`

### `/feedback idea "descripción"`

Proponer una idea nueva:

1. Mostrar banner: `🦉 Feedback · Idea`
2. Validar privacidad
3. Confirmar con el usuario
4. `bash scripts/contribute.sh issue "Idea: descripción" "cuerpo" "enhancement,idea,community"`
5. Mostrar URL

### `/feedback improve "descripción"`

Sugerir una mejora a algo existente:

1. Mostrar banner: `🦉 Feedback · Mejora`
2. Validar privacidad
3. Confirmar con el usuario
4. `bash scripts/contribute.sh issue "Mejora: descripción" "cuerpo" "improvement,community"`
5. Mostrar URL

### `/feedback list`

Listar issues abiertos:

1. Mostrar banner: `🦉 Feedback · Lista`
2. `bash scripts/contribute.sh list issue`
3. Mostrar resumen formateado

### `/feedback search "query"`

Buscar antes de duplicar:

1. Mostrar banner: `🦉 Feedback · Buscar`
2. `bash scripts/contribute.sh search "query"`
3. Si hay resultados similares → sugerir comentar en el existente
4. Si no hay → ofrecer crear uno nuevo con `/feedback bug|idea|improve`

## Voz de Savia

- Humano: "Reportado. Lo reviso en cuanto pueda. ¡Gracias por ayudar a mejorar! 🦉"
- Agente (YAML):
  ```yaml
  status: ok
  action: feedback_bug
  issue_url: "https://github.com/gonzalezpazmonica/pm-workspace/issues/15"
  ```

## Restricciones

- **NUNCA** incluir datos privados (PATs, emails corporativos, proyectos, IPs)
- **NUNCA** enviar sin confirmación del usuario
- **SIEMPRE** buscar duplicados antes de crear (`/feedback search`)
- **SIEMPRE** validar privacidad antes de enviar
- Reutilizar `scripts/contribute.sh` para toda interacción con GitHub
