# Orgchart Shapes — Draw.io XML Reference

> Shapes específicos para organigramas de equipo. Layout vertical (TB).

## Entidades

| Entidad | Shape | Fill | Border |
|---|---|---|---|
| Departamento | Container/swimlane con header | `#4472C4` | `#2F5496` |
| Equipo | Rounded rect, borde grueso (2px) | `#dae8fc` | `#6c8ebf` |
| Lead (★) | Persona, borde bold (2px) | `#d5e8d4` | `#82b366` |
| Miembro | Persona, borde normal | `#f5f5f5` | `#666666` |
| Supervisor link | Flecha punteada ascendente | — | `#999999` dashed |
| Jerarquía | Línea sólida, orthogonal, sin flecha | — | `#333333` |

## Layout

- Direction: Top-to-Bottom (TB)
- Vertical spacing entre niveles: 100px
- Horizontal spacing entre nodos: 60px
- Container padding: 20px

## XML Snippets

### Departamento (container)

```xml
<mxCell style="swimlane;startSize=30;fillColor=#4472C4;fontColor=#ffffff;
  strokeColor=#2F5496;rounded=1;arcSize=10;fontSize=14;fontStyle=1"
  vertex="1" parent="1">
  <mxGeometry x="0" y="0" width="800" height="400" as="geometry"/>
</mxCell>
```

### Equipo (rounded rect)

```xml
<mxCell style="rounded=1;whiteSpace=wrap;fillColor=#dae8fc;
  strokeColor=#6c8ebf;strokeWidth=2;fontSize=12;fontStyle=1"
  vertex="1" parent="1">
  <mxGeometry width="200" height="60" as="geometry"/>
</mxCell>
```

### Lead (persona con borde bold)

```xml
<mxCell style="shape=mxgraph.basic.person;fillColor=#d5e8d4;
  strokeColor=#82b366;strokeWidth=2;fontSize=11;fontStyle=1"
  vertex="1" parent="1">
  <mxGeometry width="80" height="90" as="geometry"/>
</mxCell>
```

### Miembro (persona normal)

```xml
<mxCell style="shape=mxgraph.basic.person;fillColor=#f5f5f5;
  strokeColor=#666666;fontSize=11" vertex="1" parent="1">
  <mxGeometry width="80" height="90" as="geometry"/>
</mxCell>
```

### Jerarquía (línea sólida)

```xml
<mxCell style="edgeStyle=orthogonalEdgeStyle;strokeColor=#333333;
  endArrow=none;exitY=1;entryY=0" edge="1" parent="1">
</mxCell>
```

### Supervisor link (punteado)

```xml
<mxCell style="edgeStyle=orthogonalEdgeStyle;strokeColor=#999999;
  dashed=1;endArrow=open;endSize=8" edge="1" parent="1">
</mxCell>
```
