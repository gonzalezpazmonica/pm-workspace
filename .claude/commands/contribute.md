---
name: contribute
description: Contribuir mejoras, ideas o correcciones al repositorio de pm-workspace en GitHub
developer_type: all
agent: none
context_cost: low
---

# /contribute {subcommand}

> 🦉 Savia te ayuda a devolver a la comunidad — propón mejoras, ideas o correcciones.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar `identity.md` + `tone.md` del perfil activo.
Ver `.claude/profiles/context-map.md`.

## Prerequisitos

- `gh` CLI instalado y autenticado (`gh auth status`)
- Repositorio clonado desde GitHub con origin configurado
- Leer `@.claude/rules/domain/community-protocol.md` para guardrails de privacidad

## Subcomandos

### `/contribute pr "título"`

Crear un Pull Request con una mejora o corrección:

1. Mostrar banner: `🦉 Contribute · PR`
2. Verificar prerequisitos (`gh`, auth, origin) — mostrar ✅/❌
3. Pedir al usuario qué quiere mejorar si no lo ha especificado
4. Generar los cambios necesarios (diff)
5. **Validar privacidad**: ejecutar `bash scripts/contribute.sh validate "contenido"` sobre TODO el diff
6. Si falla validación → mostrar qué se detectó, NO continuar
7. Confirmar con el usuario antes de enviar
8. Crear rama `community/{slug}`, commit, push, `gh pr create`
9. Mostrar URL del PR creado
10. Banner fin: `✅ PR creado`

### `/contribute idea "título"`

Abrir un issue de tipo enhancement:

1. Mostrar banner: `🦉 Contribute · Idea`
2. Validar privacidad del título y descripción
3. Confirmar con el usuario
4. `bash scripts/contribute.sh issue "título" "descripción" "enhancement,community,from-savia"`
5. Mostrar URL del issue

### `/contribute bug "título"`

Abrir un issue de tipo bug:

1. Mostrar banner: `🦉 Contribute · Bug`
2. Pedir al usuario pasos para reproducir (sanitizados)
3. Validar privacidad
4. `bash scripts/contribute.sh issue "título" "descripción" "bug,community,from-savia"`
5. Mostrar URL del issue

### `/contribute status`

Ver PRs e issues abiertos del usuario:

1. Mostrar banner: `🦉 Contribute · Status`
2. `bash scripts/contribute.sh list all`
3. Mostrar resumen formateado

## Voz de Savia

- Humano: "He creado el PR con tu mejora. ¡Gracias por contribuir! 🦉"
- Agente (YAML):
  ```yaml
  status: ok
  action: contribute_pr
  url: "https://github.com/gonzalezpazmonica/pm-workspace/pull/42"
  ```

## Restricciones

- **NUNCA** incluir datos privados: PATs, emails corporativos, nombres de proyecto, IPs, connection strings
- **NUNCA** enviar sin confirmación explícita del usuario
- **SIEMPRE** ejecutar `validate_privacy` antes de cualquier envío
- **SIEMPRE** incluir versión de pm-workspace en el cuerpo del PR/issue
- Los PRs solo tocan ficheros de `commands/`, `rules/`, `scripts/`, `docs/` — NUNCA `profiles/`, `projects/`, `output/`
