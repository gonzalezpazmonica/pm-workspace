# Estructura de Boards Miro para Diagramas

> Referencia para la skill `diagram-generation`. Define cómo organizar boards y frames en Miro.

## Estructura del Board

Cada proyecto tiene un board en Miro con la siguiente organización:

```
Board: "{Proyecto} — Diagrams"
├── Frame: "Architecture"           ← Diagrama de arquitectura principal
├── Frame: "Data Flow"              ← Flujos de datos entre componentes
├── Frame: "Sequence — {caso}"      ← Diagrama de secuencia por caso de uso
├── Frame: "Deployment"             ← Topología de despliegue
└── Frame: "Notes & Decisions"      ← Notas de arquitectura, ADRs
```

## Mapeo Entidades → Items Miro

| Entidad | Miro Item | Color | Tamaño |
|---|---|---|---|
| Microservicio | Shape (rectangle) | `#4FC3F7` (azul) | 200x100 |
| Base de datos | Shape (cylinder/circle) | `#FFB74D` (naranja) | 150x100 |
| Cola/Bus | Shape (hexagon) | `#BA68C8` (púrpura) | 180x80 |
| Frontend | Shape (rounded rect) | `#81C784` (verde) | 200x100 |
| Externo | Shape (rectangle dashed) | `#E0E0E0` (gris) | 180x80 |
| Cache | Shape (diamond) | `#FFD54F` (amarillo) | 120x120 |

## Conectores Miro

| Relación | Estilo | Color |
|---|---|---|
| HTTP sync | Línea sólida con flecha | `#1565C0` |
| Async/Evento | Línea discontinua con flecha | `#7B1FA2` |
| Lectura DB | Línea sólida fina | `#2E7D32` |
| Escritura DB | Línea sólida gruesa | `#C62828` |

## Uso del MCP Miro

El MCP `miro` (mcp.miro.com) expone herramientas para:
- Crear/listar boards
- Crear shapes, connectors, sticky notes, frames
- Leer contenido de un board (shapes + connectors)
- Buscar items por texto

### Flujo de creación

1. Verificar `MIRO_BOARD_ID` del proyecto → si no existe, crear board nuevo
2. Crear frame con nombre del tipo de diagrama
3. Dentro del frame, crear shapes por cada entidad detectada
4. Crear connectors entre shapes según relaciones
5. Añadir sticky notes con metadata (versión, fecha, autor)
6. Retornar URL del board + frame

### Flujo de lectura (para import)

1. Obtener board por ID
2. Leer todos los items del board/frame
3. Clasificar shapes por tipo visual → entidad de dominio
4. Extraer texto de cada shape como nombre/descripción
5. Leer connectors para extraer relaciones
6. Retornar modelo normalizado de entidades + relaciones
