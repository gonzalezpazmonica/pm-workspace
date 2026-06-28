---
id: web-security-headers-policy
context_tier: L2
token_budget: 1400
resource: internal://docs/rules/domain/web-security-headers-policy.md
---

# Web Security Headers Policy

> Headers obligatorios para todo proyecto web generado por Savia.
> Verificación: `scripts/web-headers-check.sh --url <url>`.

## Headers Obligatorios

### Content-Security-Policy (CSP) — 25 pts

```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'
```

### Strict-Transport-Security (HSTS) — 20 pts

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

`max-age >= 31536000` (1 año mínimo). `preload` sólo si en lista HSTS preload.

### X-Content-Type-Options — 15 pts

```
X-Content-Type-Options: nosniff
```

### X-Frame-Options — 15 pts

```
X-Frame-Options: DENY
```

O equivalente vía CSP: `frame-ancestors 'none'`.

### Referrer-Policy — 15 pts

```
Referrer-Policy: strict-origin-when-cross-origin
```

### Permissions-Policy — 10 pts

```
Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()
```

## Headers Prohibidos

```
Server: Apache/2.4.x    ← NO exponer versión
X-Powered-By: Express   ← NO exponer stack tecnológico
```

## Configuración por Framework

### Express / NestJS

```typescript
import helmet from 'helmet';
app.use(helmet({
  contentSecurityPolicy: { directives: { defaultSrc: ["'self'"], objectSrc: ["'none'"] } },
  hsts: { maxAge: 31536000, includeSubDomains: true },
  frameguard: { action: 'deny' },
}));
```

### ASP.NET Core

```csharp
app.Use(async (ctx, next) => {
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"] = "DENY";
    ctx.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    ctx.Response.Headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
    await next();
});
```

### FastAPI (Python)

```python
from starlette.middleware.base import BaseHTTPMiddleware
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Content-Security-Policy"] = "default-src 'self'; object-src 'none'"
        return response
app.add_middleware(SecurityHeadersMiddleware)
```

### Gin (Go)

```go
r.Use(func(c *gin.Context) {
    c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
    c.Header("X-Content-Type-Options", "nosniff")
    c.Header("X-Frame-Options", "DENY")
    c.Header("Content-Security-Policy", "default-src 'self'; object-src 'none'")
    c.Next()
})
```

### Axum (Rust)

```rust
async fn security_headers<B>(req: Request<B>, next: Next<B>) -> Response {
    let mut res = next.run(req).await;
    let h = res.headers_mut();
    h.insert("strict-transport-security", HeaderValue::from_static("max-age=31536000; includeSubDomains"));
    h.insert("x-content-type-options", HeaderValue::from_static("nosniff"));
    h.insert("x-frame-options", HeaderValue::from_static("DENY"));
    h.insert("content-security-policy", HeaderValue::from_static("default-src 'self'; object-src 'none'"));
    res
}
```

## Scoring y gates

| Score | Estado | Acción |
|-------|--------|--------|
| 80-100 | PASS | Deploy autorizado |
| 60-79 | WARN | Deploy con ticket |
| < 60 | BLOCK | Deploy bloqueado hasta corregir HIGH findings |

Report en `output/security/headers-check-{hostname}-YYYYMMDD.json` (N3, gitignoreado).
