---
name: security-audit
description: >
  Auditoría de seguridad SAST sobre ficheros del proyecto.
  Análisis estático de vulnerabilidades contra OWASP Top 10 (2021).
agent: security-guardian
skills:
  - azure-devops-queries
tier: extended
---

# /security-audit

Ejecuta un análisis estático de seguridad (SAST) sobre los ficheros del proyecto activo.

---

## Flujo

### 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Governance** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar idioma y nivel de detalle según `preferences.language` y `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

### 2. Banner inicio

```
╔══════════════════════════════════════╗
║  🔒 Security Audit (SAST)           ║
╚══════════════════════════════════════╝
```

### 3. Prerequisitos

- ✅/❌ Proyecto activo identificado
- ✅/❌ Ficheros fuente encontrados

### 4. Análisis por categoría OWASP Top 10

Revisar contra:

1. **A01: Broken Access Control** — hardcoded roles, missing auth checks
2. **A02: Cryptographic Failures** — weak algorithms (MD5, SHA1), hardcoded keys
3. **A03: Injection** — unsanitized inputs, raw SQL, eval(), template injection
4. **A04: Insecure Design** — missing rate limiting, no input validation
5. **A05: Security Misconfiguration** — debug mode, verbose errors, defaults
6. **A07: XSS** — unescaped output, innerHTML, dangerouslySetInnerHTML
7. **A09: Logging Failures** — sensitive data in logs, missing audit trail
8. **A10: SSRF** — unvalidated URLs, user-controlled redirects

### 5. Formato de resultados

Para cada hallazgo:

```
🔴 CRITICAL | 🟡 WARNING | 🔵 INFO

[Severidad] A0X: {categoría}
  Fichero: {ruta}:{línea}
  Hallazgo: {descripción}
  Recomendación: {fix sugerido}
```

### 6. Resumen

```
📊 Security Audit:
  🔴 Critical: X | 🟡 Warning: Y | 🔵 Info: Z
  Ficheros analizados: N
  Duración: ~45s
```

### 7. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Security Audit — Completo       ║
╚══════════════════════════════════════╝
📄 Detalle: output/security-audits/YYYYMMDD-audit-{proyecto}.md
⚡ /compact
```

