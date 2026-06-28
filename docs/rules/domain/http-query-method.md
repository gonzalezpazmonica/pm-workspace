---
id: http-query-method
context_tier: L2
token_budget: 900
rfc: "RFC 10008 — https://www.rfc-editor.org/rfc/rfc10008"
status: ACTIVE
updated: "2026-06-27"
---

# HTTP QUERY Method (RFC 10008)

## Qué es

QUERY es un método HTTP estándar (Standards Track, IETF HTTPbis WG, junio 2026).
Definición: **GET con body** — para consultas complejas que no caben en la query string.

| Propiedad    | Valor |
|---|---|
| Safe         | YES — no modifica estado del servidor |
| Idempotente  | YES — misma request produce mismo resultado |
| Cacheable    | YES — igual que GET (RFC 9111 §4) |
| Request body | PERMITIDO — Content-Type obligatorio |
| CORS         | Requiere preflight (no es safelisted method) |

Headers específicos:
- `Accept-Query` (response): anuncia soporte y media types aceptados
- `Content-Location` (response): URI del resultado concreto (caché)
- `Location` (response): URI equivalente GET sin body

## Cuándo usar QUERY vs GET / POST

| Situación | Método correcto |
|---|---|
| Recurso simple, criterios en URL ≤ 2KB | `GET` |
| Criterios complejos, filtros nested, body necesario | `QUERY` |
| Operación con efectos secundarios o creación | `POST` |
| Búsqueda en colecciones WebDAV (legado) | `SEARCH` |
| GraphQL query (sin mutation) | `QUERY` — semánticamente correcto |

## Patrón servidor (genérico)

1. Leer body → validar Content-Type → rechazar con 400 si ausente o inválido
2. Deserializar criterios de consulta del body
3. Ejecutar consulta (solo lectura, sin efectos secundarios)
4. Responder 200 con `Accept-Query: application/json` en el header

Códigos de respuesta:
- `200` — resultados; `204` — sin resultados; `400` — sin Content-Type
- `415` — media type no soportado (incluir `Accept-Query`); `422` — query inválida

## Patrón cliente (genérico)

```
METHOD: QUERY
Content-Type: application/json
Body: { criterios de búsqueda }
```

curl: `curl -X QUERY -H "Content-Type: application/json" -d '{"q":"foo"}' URL`

## Tabla de soporte por plataforma (junio 2026)

| Plataforma | Soporte | Workaround |
|---|---|---|
| curl | ✅ Nativo (`-X QUERY`) | — |
| Node.js ≥ 21.7.2 | ✅ Nativo | — |
| fetch() (browsers) | ✅ Con preflight | — |
| axios ≥ 2026-04-28 | ✅ `axios.query()` | — |
| Express.js | ✅ `app.query()` | — |
| ASP.NET Core | ✅ Parcial (PR #63276) | `[AcceptVerbs("QUERY")]` |
| http crate (Rust) | ✅ `Method::QUERY` desde 2026-06-16 | — |
| FastAPI / Starlette | ⚠️ Sin shorthand | `methods=["QUERY"]` en route |
| Flask / Werkzeug | ⚠️ PR #6066 abierto | `@app.route(..., methods=["QUERY"])` |
| Go net/http | ⚠️ Issue #80058 abierto | `r.Method == "QUERY"` |
| Gin (Go) | ⚠️ Issue #4097 abierto | `r.Handle("QUERY", ...)` |
| Axum (Rust) | ⚠️ PR #3801 abierto | `any()` + filtro manual |
| reqwest (Rust) | ⚠️ Sin constante aún | `Method::from_bytes(b"QUERY")` |
| Spring Framework | ⚠️ PR #34993 abierto | `HttpMethod.valueOf("QUERY")` |
| Fastify | ⚠️ Issue #6807 abierto | Plugin `@thecodepace/fastify-http-query` |

## Workaround universal cuando no hay soporte nativo

**Python (Flask/FastAPI):**
```python
@app.route('/path', methods=['QUERY'])
async def handler(request): ...
```

**TypeScript (fallback si app.query() no existe):**
```typescript
app.all('/path', (req, res) => {
  if (req.method !== 'QUERY') { res.status(405).end(); return; }
  // ...
});
```

**Go:**
```go
const MethodQuery = "QUERY"  // hasta que llegue MethodQuery a stdlib
```

**Java (Spring):**
```java
webClient.method(HttpMethod.valueOf("QUERY")).uri("/path")...
```

## Ejemplos ejecutables

Ver `scripts/examples/http-query/` — servidor y cliente en 6 lenguajes:
- `server-express.ts`, `server-fastapi.py`, `server-aspnet.cs`, `server-gin.go`
- `client-curl.sh`, `client-fetch.ts`, `client-python.py`, `client-go.go`
- `client-csharp.cs`, `client-rust.rs`, `client-java.java`
