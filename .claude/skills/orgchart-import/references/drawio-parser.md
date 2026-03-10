# Draw.io Parser — Orgchart Import

> Parsea ficheros `.drawio` / `.xml` basandose en shapes de `orgchart-shapes.md`.

## Identificacion de entidades por estilo

### Departamento

- Style: `swimlane` con `fillColor=#4472C4`
- Texto del header = nombre del departamento
- Buscar atributo `value` con HTML: extraer texto plano
- Responsable: buscar "Responsable:" en el contenido del nodo

```xml
<mxCell style="swimlane;startSize=30;fillColor=#4472C4;..." value="Engineering">
```

### Equipos

- Style: `rounded=1` con `strokeWidth=2` y `fillColor=#dae8fc`
- Son hijos (parent) del container departamento
- `value` contiene nombre del equipo
- Capacity: buscar "(cap: N)" en el value, o calcular desde miembros

```xml
<mxCell style="rounded=1;...fillColor=#dae8fc;strokeColor=#6c8ebf;strokeWidth=2"
  value="Squad1 (cap: 2.0)" parent="{dept_id}">
```

### Miembros Lead

- Style: `shape=mxgraph.basic.person` con `fillColor=#d5e8d4` y `strokeWidth=2`
- Color verde (`#d5e8d4`) + borde grueso (2px) = lead
- `value` contiene HTML: `@handle<br/>role` o `@handle<br/>role ★`
- Extraer handle y role del HTML

```xml
<mxCell style="shape=mxgraph.basic.person;fillColor=#d5e8d4;strokeWidth=2"
  value="@eduardo&lt;br/&gt;tech-lead" parent="{team_id}">
```

### Miembros regulares

- Style: `shape=mxgraph.basic.person` con `fillColor=#f5f5f5`
- Borde normal (sin strokeWidth=2)
- Mismo parseo de value que leads

```xml
<mxCell style="shape=mxgraph.basic.person;fillColor=#f5f5f5"
  value="@daniel&lt;br/&gt;developer" parent="{team_id}">
```

### Supervisor links

- Style: `dashed=1` con `strokeColor=#999999`
- `source` y `target` referencian IDs de nodos miembro
- Extraer handles de los nodos referenciados

### Jerarquia dept-team

- Style: `edgeStyle=orthogonalEdgeStyle` con `endArrow=none`
- Linea solida entre dept y equipo
- Confirma relacion parent (ya implicita por parent XML)

## Algoritmo de parseo

1. Parsear XML, construir mapa `id → mxCell`
2. Identificar departamento: swimlane con `#4472C4`
3. Identificar equipos: hijos del dept con `rounded=1;strokeWidth=2`
4. Identificar miembros por equipo: hijos con `shape=mxgraph.basic.person`
5. Clasificar lead/regular por `fillColor` (#d5e8d4 vs #f5f5f5)
6. Extraer handle/role del atributo `value` (desescapar HTML entities)
7. Buscar edges dashed para supervisor links

## Fallbacks

- Si no hay swimlane azul: buscar container mas grande como dept
- Si shapes no coinciden exactamente: warn + heuristico por posicion
- Si value no tiene `@`: proponer como handle al usuario
- HTML entities: `&lt;` → `<`, `&gt;` → `>`, `&amp;` → `&`
