# Detección de Componentes Arquitectónicos

## Matriz de Detección

| Entidad | Detección | Icono Mermaid |
|---|---|---|
| Microservicio / API | `*.csproj` + `Sdk="Microsoft.NET.Sdk.Web"`, `Dockerfile` | `[Nombre]` box |
| Base de datos | `ConnectionString`, `DbContext`, `azurerm_sql_*` en TF | `[(DB)]` cylinder |
| Cola / Bus | `ServiceBus`, `RabbitMQ`, `AzureServiceBus` en config | `{{Cola}}` hexagon |
| Almacenamiento | `BlobStorage`, `S3`, `azurerm_storage_*` | `[/Storage/]` parallelogram |
| API Gateway | `Ocelot`, `YARP`, `Kong`, `azurerm_api_management` | `[[Gateway]]` subroutine |
| Frontend / SPA | `angular.json`, `next.config.*`, `vite.config.*` | `(Frontend)` rounded |
| Servicio externo | Referencias APIs externas, SDKs terceros | `>Externo]` asymmetric |
| CDN / Cache | `Redis`, `azurerm_cdn_*`, `CloudFront` | `{Cache}` rhombus |

## Relaciones a Detectar

- **HTTP/REST** — Referencias entre proyectos, `HttpClient`, Swagger refs
- **Mensajería** — Productores/consumidores de colas/topics
- **Base de datos** — Qué servicios acceden a qué DBs
- **Dependencia directa** — Project references, imports, packages compartidos
