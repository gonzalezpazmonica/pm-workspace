# Mapeo Entidades → Shapes Draw.io

> Referencia para la skill `diagram-generation`. Define cómo representar cada tipo de entidad al exportar a Draw.io XML.

## Shapes por tipo de entidad

| Entidad | Draw.io Shape | Style |
|---|---|---|
| Microservicio | `mxgraph.aws4.lambda` o rectángulo rounded | `rounded=1;whiteSpace=wrap;fillColor=#dae8fc;strokeColor=#6c8ebf` |
| API Gateway | `mxgraph.aws4.api_gateway` o doble borde | `shape=mxgraph.flowchart.multi-document;fillColor=#d5e8d4;strokeColor=#82b366` |
| Base de datos | Cilindro | `shape=cylinder3;whiteSpace=wrap;fillColor=#fff2cc;strokeColor=#d6b656` |
| Cola/Bus | Hexágono | `shape=hexagon;fillColor=#e1d5e7;strokeColor=#9673a6` |
| Almacenamiento | Paralelogramo | `shape=parallelogram;fillColor=#f8cecc;strokeColor=#b85450` |
| Frontend/SPA | Rectángulo rounded | `rounded=1;fillColor=#dae8fc;strokeColor=#6c8ebf;fontStyle=1` |
| Servicio externo | Rectángulo gris | `fillColor=#f5f5f5;strokeColor=#666666;dashed=1` |
| Cache | Rombo | `rhombus;fillColor=#fff2cc;strokeColor=#d6b656` |
| Load Balancer | Elipse | `ellipse;fillColor=#d5e8d4;strokeColor=#82b366` |
| CDN | Nube | `shape=cloud;fillColor=#dae8fc;strokeColor=#6c8ebf` |

## Conectores

| Relación | Style Draw.io |
|---|---|
| HTTP/REST sync | `endArrow=classic;strokeColor=#0000FF` |
| Mensajería async | `endArrow=classic;dashed=1;strokeColor=#9900FF` |
| Lectura DB | `endArrow=classic;strokeColor=#009900` |
| Escritura DB | `endArrow=classic;strokeWidth=2;strokeColor=#CC0000` |
| Dependencia | `endArrow=open;dashed=1;strokeColor=#999999` |

## Layout recomendado

- **Horizontal (LR)**: Para flujos de datos (request → response)
- **Vertical (TB)**: Para arquitectura por capas (frontend → backend → data)
- **Spacing**: minX=80, minY=60 entre nodos
- **Subgraphs**: Usar containers/groups para capas o bounded contexts

## XML base para diagrama vacío

```xml
<mxfile>
  <diagram name="Architecture">
    <mxGraphModel>
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- Entities and connections go here -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
