# Regla: Configuración de Diagramas de Arquitectura
# ── Constantes y configuración para generación e importación de diagramas ────

> Esta regla se carga bajo demanda cuando se ejecutan comandos `diagram-*`.

```
# ── MCP Tools disponibles ────────────────────────────────────────────────────
DIAGRAM_TOOL_DRAWIO         = "draw-io"                          # Draw.io oficial (HTTP, sin auth básica)
DIAGRAM_TOOL_MIRO           = "miro"                             # Miro oficial (HTTP, OAuth 2.1)
DIAGRAM_DEFAULT_TOOL        = "draw-io"                          # Tool por defecto si no se especifica

# ── URLs MCP ─────────────────────────────────────────────────────────────────
DRAWIO_MCP_URL              = "https://mcp.draw.io/mcp"          # Endpoint HTTP oficial Draw.io
MIRO_MCP_URL                = "https://mcp.miro.com"             # Endpoint HTTP oficial Miro

# ── Credenciales ─────────────────────────────────────────────────────────────
MIRO_TOKEN_FILE             = "$HOME/.azure/miro-token"           # OAuth token Miro (una línea, sin salto)
# Draw.io HTTP oficial no requiere auth para operaciones básicas

# ── Tipos de diagrama soportados ─────────────────────────────────────────────
DIAGRAM_TYPES               = "architecture,flow,sequence"
DIAGRAM_DEFAULT_TYPE        = "architecture"

# ── Formatos ─────────────────────────────────────────────────────────────────
DIAGRAM_FORMAT_DRAWIO       = "xml"                              # Draw.io nativo: XML (.drawio)
DIAGRAM_FORMAT_MIRO         = "json"                             # Miro API: JSON
DIAGRAM_FORMAT_LOCAL        = "mermaid"                          # Local: Mermaid (.mermaid)

# ── Estructura por proyecto ──────────────────────────────────────────────────
# projects/{proyecto}/diagrams/draw-io/    ← metadata de diagramas Draw.io
# projects/{proyecto}/diagrams/miro/       ← metadata de boards Miro
# projects/{proyecto}/diagrams/local/      ← diagramas locales (.mermaid, .xml)
DIAGRAM_DIR                 = "diagrams"
DIAGRAM_META_EXTENSION      = ".meta.json"
```

## Validación de reglas de negocio

Antes de crear PBIs desde un diagrama, se DEBE verificar que existan reglas de negocio suficientes. El fichero `projects/{proyecto}/reglas-negocio.md` debe contener información para cada entidad del diagrama según su tipo:

| Tipo entidad | Información requerida |
|---|---|
| Microservicio | Interfaz/contrato, esquema DB, entorno deploy |
| API/Endpoint | Método HTTP, path, autenticación, rate limit |
| Base de datos | Esquema, política backup, plan escalado |
| UI/Frontend | User stories, requisitos accesibilidad |
| Cola/Mensajería | Formato mensaje, política reintentos, DLQ |
| Integración externa | Proveedor, SLA, fallback |

Si falta información → NO se crean PBIs. Se genera informe de info faltante para el PM.
