# Spec: SE-298 — WikiLink Enhancement for Knowledge Graph

**Task ID:**        SE-298
**PBI padre:**      SE-298 — WikiLink bidirectional navigation
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-03
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 45 min |
| Human effort | 2 h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 1h |

---

## 1. Contexto y Objetivo

El knowledge graph de SaviaVaults (SE-288) ya detecta `[[wikilinks]]` en
el contenido de las notas y crea relaciones MENTIONS (linea 69 de graph.ts).
Esto funciona pero es invisible: el usuario escribe wikilinks sin saber si
apuntan a entidades reales, y no hay forma de ver que notas enlazan a una
entidad (backlinks).

Objetivo: hacer los wikilinks **visibles, validados y navegables**.

- Validacion: detectar wikilinks rotos (apuntan a entidades inexistentes)
- Backlinks: `vault_read` muestra que notas enlazan a esta (incoming MENTIONS)
- Health: informe de salud incluye wikilinks rotos como warning
- Obsidian compatibility: nada que rompa la apertura en Obsidian
- Zero overhead: la extraccion ya existe en graph.ts. Solo añadir visibilidad.

---

## 2. Contrato Tecnico

### 2.1 WikiLink Validator

```typescript
// src/knowledge/wikilink-validator.ts
interface WikiLinkValidation {
  source: string;       // path de la nota que contiene el wikilink
  target: string;       // nombre de la entidad referenciada
  exists: boolean;      // true si la entidad existe en el vault
  line?: number;        // linea del wikilink en la nota
}

class WikiLinkValidator {
  validate(vaultPath: string, notes: Note[]): WikiLinkValidation[] {
    // Extrae todos los [[wikilinks]] de todas las notas
    // Verifica si cada target existe como entidad en el vault
    // Retorna lista de validaciones (con broken links marcados)
  }
}
```

### 2.2 Backlink Display en vault_read

```typescript
// Al leer una nota via MCP vault_read, incluir backlinks
interface BacklinkInfo {
  source: string;        // nota que enlaza a esta
  context: string;       // snippet alrededor del wikilink
}

// vault_read response extendido:
interface VaultReadResult {
  path: string;
  content: string;
  frontmatter: Record<string, unknown>;
  tags: string[];
  backlinks?: BacklinkInfo[];     // NEW: incoming wikilinks (opcional, no rompe schema)
  outgoingLinks?: string[];       // NEW: outgoing wikilinks (opcional)
}
```

### 2.3 Health Report Enhancement

```typescript
// Añadir seccion de wikilinks al health report existente
interface WikiLinkHealth {
  total_links: number;
  valid_links: number;
  broken_links: number;
  orphan_entities: string[];    // entidades sin incoming links
  most_linked: { entity: string; count: number }[];
}
```

---

## 3. Reglas de Negocio

### RB-001: WikiLink syntax
Los wikilinks usan `[[nombre-entidad]]` o `[[nombre-entidad|alias]]`.
El alias es solo para display. La referencia siempre apunta al nombre antes del `|`.

### RB-002: Entity matching
Un wikilink `[[SE-291]]` busca una entidad cuyo name o id coincida exactamente
(primero id, luego name). Case-insensitive.

### RB-003: Broken link detection
Wikilinks que apuntan a entidades inexistentes se marcan como broken.
No se crea relacion MENTIONS para broken links.

### RB-004: Backlinks in vault_read
Al leer una nota, se incluyen los backlinks (notas que enlazan a esta via [[wikilink]]).
Los backlinks solo muestran la primera linea de contexto alrededor del wikilink.

### RB-005: Health integration
El health report incluye wikilink metrics como seccion adicional.
Broken links > 10% del total → WARN en health status.

### RB-006: Obsidian compatibility
Los wikilinks usan exactamente la sintaxis de Obsidian (`[[target]]`).
Cero modificaciones al formato de almacenamiento.
Abrir el vault en Obsidian debe funcionar identico.

---

## 4. Constraints and Limits

- Max 50 backlinks por nota (para evitar respuestas enormes)
- Max 200 caracteres de contexto por backlink
- Validacion de wikilinks: se ejecuta como parte del build del grafo (no en cada lectura)
- No auto-completion (requiere editor integration, fuera de scope)

---

## 5. Test Scenarios

### TC-001: WikiLink extraction
```
GIVEN nota A con contenido "Ver [[SE-291]] para detalles"
AND nota B con frontmatter entity.id = "SE-291"
WHEN se construye el grafo
THEN relacion MENTIONS existe desde A hacia SE-291
```

### TC-002: Broken link detection
```
GIVEN nota con "[[entidad-inexistente]]"
WHEN WikiLinkValidator procesa
THEN validation result: exists=false
AND no se crea relacion MENTIONS
```

### TC-003: Backlinks via vault_read
```
GIVEN tres notas enlazan a "SE-291" via [[wikilink]]
WHEN vault_read("SE-291")
THEN backlinks contiene 3 entradas
AND cada entrada muestra el path fuente + contexto
```

### TC-004: Health report includes wikilinks
```
GIVEN vault con 20 wikilinks, 3 broken
WHEN health report se genera
THEN wikilink_health.broken_links = 3
AND wikilink_health.total_links = 20
AND status incluye WARN (15% broken > 10%)
```

### TC-005: Obsidian roundtrip
```
GIVEN nota con [[wikilink-alias|Alias Amigable]]
WHEN se lee y escribe de vuelta
THEN el wikilink se preserva intacto
AND Obsidian lo renderiza correctamente
```

---

## 6. Ficheros

### Crear

| Fichero | Proposito |
|---|---|
| `projects/savia-vaults/src/knowledge/wikilink-validator.ts` | Validador de wikilinks |
| `projects/savia-vaults/tests/unit/knowledge/wikilink-validator.test.ts` | Tests |
| `projects/savia-vaults/tests/unit/knowledge/wikilink-backlinks.test.ts` | Tests backlinks |

### Modificar

| Fichero | Cambio |
|---|---|
| `projects/savia-vaults/src/knowledge/graph.ts` | Añadir validacion de broken links |
| `projects/savia-vaults/src/knowledge/quality.ts` | Añadir wikilink metrics al health report |
| `projects/savia-vaults/src/server/mcp.ts` | Añadir backlinks a vault_read, vault_search |
| `projects/savia-vaults/src/knowledge/index.ts` | Exportar WikiLinkValidator |

---

## 7. Estado de Implementacion

| Slice | Horas | Descripcion |
|---|---|---|
| S1: WikiLink validator | 2h | Extraccion + validacion + broken link detection |
| S2: Backlinks en vault_read | 2h | Añadir backlinks y outgoingLinks a la respuesta |
| S3: Health metrics | 1h | WikiLink seccion en health report |
| S4: Tests | 1h | Tests de validacion, backlinks, health |

**Total: ~6h (4 slices)**

---

## 8. Criterios de Aceptacion

- [ ] AC1: WikiLinkValidator detecta wikilinks en contenido de notas
- [ ] AC2: Broken links (target inexistente) se reportan, no crean MENTIONS
- [ ] AC3: vault_read incluye backlinks (notas que enlazan a esta)
- [ ] AC4: vault_read incluye outgoingLinks (wikilinks en esta nota)
- [ ] AC5: Health report incluye wikilink metrics (total, valid, broken, most_linked)
- [ ] AC6: Sintaxis [[target]] y [[target|alias]] soportada
- [ ] AC7: Notas con wikilinks siguen siendo compatibles con Obsidian
- [ ] AC8: Rendimiento: validacion <100ms para vault de 100 notas
