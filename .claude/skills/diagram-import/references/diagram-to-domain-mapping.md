# Mapeo Diagrama → Entidades de Dominio

> Referencia para la skill `diagram-import`. Reglas de reconocimiento para clasificar shapes/nodos del diagrama en entidades de dominio.

## Reconocimiento por forma visual

### Draw.io XML

| Style attribute | Entidad |
|---|---|
| `shape=cylinder3` | Base de datos |
| `shape=hexagon` | Cola / Bus de mensajería |
| `rhombus` | Cache o punto de decisión |
| `shape=cloud` | CDN o servicio cloud |
| `rounded=1` + color azul | Frontend / SPA |
| `dashed=1` | Servicio externo |
| `shape=mxgraph.flowchart.multi-document` | API Gateway |
| Rectángulo estándar | Microservicio / API |

### Mermaid

| Sintaxis | Entidad |
|---|---|
| `[(nombre)]` | Base de datos |
| `{{nombre}}` | Cola / Bus |
| `{nombre}` | Cache / Decisión |
| `(nombre)` | Frontend (rounded) |
| `>nombre]` | Servicio externo |
| `[[nombre]]` | API Gateway / Subroutine |
| `[nombre]` | Microservicio / API |

### Miro shapes

| Shape type | Entidad |
|---|---|
| Circle / Cylinder | Base de datos |
| Hexagon | Cola / Bus |
| Diamond | Cache / Decisión |
| Rounded rectangle (verde) | Frontend |
| Rectangle (gris/dashed) | Servicio externo |
| Rectangle (azul) | Microservicio / API |

## Reconocimiento por texto/nombre

Si la forma no es determinante, analizar el nombre/label:

| Patrón en nombre | Entidad |
|---|---|
| `*DB`, `*Database`, `*Store`, `SQL*`, `Mongo*`, `Postgres*` | Base de datos |
| `*Queue`, `*Bus`, `*Topic`, `Service Bus`, `RabbitMQ`, `Kafka` | Cola / Bus |
| `*Cache`, `Redis`, `Memcached` | Cache |
| `*Gateway`, `*Proxy`, `BFF`, `Ocelot`, `YARP`, `Kong` | API Gateway |
| `*UI`, `*App`, `*Web`, `*SPA`, `Angular*`, `React*`, `*Frontend` | Frontend |
| `*CDN`, `CloudFront`, `Akamai` | CDN |
| `*Storage`, `Blob*`, `S3*`, `*Bucket` | Almacenamiento |
| Nombre de empresa externa (Stripe, Twilio, SendGrid, etc.) | Servicio externo |

## Reconocimiento de relaciones

| Patrón | Tipo de relación |
|---|---|
| Flecha sólida con label HTTP verb (GET, POST, PUT, DELETE) | HTTP sync |
| Flecha sólida sin label entre servicio y servicio | HTTP sync (inferir) |
| Flecha discontinua / con label event/message | Async / Mensajería |
| Flecha hacia DB | Acceso a datos (R/W según contexto) |
| Flecha bidireccional | Dependencia mutua (⚠️ posible antipatrón) |
| Línea sin flecha | Asociación / pertenencia al mismo grupo |

## Modelo de salida normalizado

Cada entidad parseada produce:

```json
{
  "id": "kebab-case-unico",
  "name": "Nombre legible",
  "type": "microservice|database|queue|cache|frontend|gateway|storage|external|cdn",
  "description": "Extraído del label o generado",
  "metadata": {},
  "business_rules_status": "pending|complete|partial",
  "missing_fields": []
}
```

Cada relación produce:

```json
{
  "from": "id-origen",
  "to": "id-destino",
  "type": "http-sync|async|data-read|data-write|dependency",
  "label": "Texto del label si existe",
  "bidirectional": false
}
```
