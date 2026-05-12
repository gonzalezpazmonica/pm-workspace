---
name: diagram-config
description: >
  Configurar credenciales y conexión con Draw.io y/o Miro MCP.
  Verifica la conexión y guía en el setup inicial.
---

# Configuración de Herramientas de Diagramas

**Tool:** $ARGUMENTS

> Uso: `/diagram-config --tool draw.io|miro [--test] [--list]`

## Parámetros

- `--tool {draw.io|miro}` — Herramienta a configurar (obligatorio salvo `--list`)
- `--test` — Verificar conexión al MCP sin modificar nada
- `--list` — Mostrar estado de configuración de todas las herramientas
- `--set-token` — Configurar token/credencial (solo Miro; Draw.io no requiere)

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Diagramas** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar etiquetas según `preferences.language`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. `docs/rules/domain/diagram-config.md` — Constantes y URLs
2. `.claude/mcp.json` — Configuración MCP actual
3. `docs/rules/domain/pm-config.md` — Credenciales generales

## 4. Pasos de ejecución

### Si `--list`

Mostrar tabla de estado:

```
🔧 Herramientas de Diagramas

┌──────────┬──────────────┬────────────┬──────────────────┐
│ Tool     │ MCP URL      │ Auth       │ Estado           │
├──────────┼──────────────┼────────────┼──────────────────┤
│ Draw.io  │ mcp.draw.io  │ No req.    │ ✅ Configurado   │
│ Miro     │ mcp.miro.com │ OAuth 2.1  │ ⚠️ Sin token    │
└──────────┴──────────────┴────────────┴──────────────────┘
```

### Si `--tool draw.io`

1. Verificar que `.claude/mcp.json` contiene la entrada `draw-io`
2. Si no existe → informar al usuario que debe añadirla (mostrar JSON exacto)
3. Si `--test` → intentar listar diagramas via MCP draw-io
4. Mostrar resultado: ✅ Conexión OK / ❌ Error + detalle

### Si `--tool miro`

1. Verificar que `.claude/mcp.json` contiene la entrada `miro`
2. Verificar que existe `$HOME/.azure/miro-token` con contenido
3. Si falta token → guiar al usuario:
   ```
   Para configurar Miro:
   1. Ve a https://miro.com/app/settings/user-profile/apps
   2. Crea una app o usa una existente
   3. Copia el Access Token
   4. Guárdalo: echo "TU_TOKEN" > $HOME/.azure/miro-token
   ```
4. Si `--test` → intentar listar boards via MCP miro
5. Si `--set-token` → solicitar token al usuario, validar formato, guardar en fichero
6. Mostrar resultado: ✅ Conexión OK / ❌ Error + detalle

### Si `--tool` sin `--test` ni `--set-token`

Mostrar configuración actual del tool y estado de conexión.

## Restricciones

- **No almacenar tokens en código ni en ficheros trackeados por git**
- Tokens van en `$HOME/.azure/` (mismo patrón que PAT Azure DevOps)
- Solo mostrar últimos 4 caracteres del token en pantalla
- Si el usuario pega un token en el chat → advertir que debe guardarlo en fichero
