---
id: SPEC-033
title: SPEC-033: Security Skills Modulares
status: PROPOSED
origin_date: "2026-03-23"
migrated_at: "2026-04-19"
migrated_from: body-prose
priority: media
---

# SPEC-033: Security Skills Modulares

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.30
> Origen: Análisis de usestrix/strix — 10 categorías de skills de seguridad
> Impacto: Mejora precisión de agentes cargando conocimiento relevante

---

## Problema

Nuestros agentes de seguridad (security-attacker, pentester) tienen su
conocimiento embebido en el prompt del agente. Todo el conocimiento se
carga siempre, independientemente del tipo de aplicación o vulnerabilidad.

Strix tiene 10 categorías de skills que se cargan dinámicamente (max 5
por sesión) según el contexto del target. Esto reduce ruido y mejora
precisión.

## Solución

Extraer el conocimiento de seguridad a skills modulares que se carguen
según el stack tecnológico y tipo de aplicación del proyecto.

## Catálogo de skills de seguridad

```
.opencode/skills/security-testing/
  SKILL.md                    -- Índice y protocolo de carga
  DOMAIN.md                   -- Clara Philosophy
  categories/
    injection.md              -- SQLi, NoSQLi, LDAP, OS command
    authentication.md         -- Broken auth, session mgmt, JWT
    access-control.md         -- IDOR, privilege escalation, RBAC
    xss.md                    -- Reflected, stored, DOM-based
    ssrf.md                   -- SSRF, CSRF, request forgery
    cryptography.md           -- Weak crypto, key mgmt, TLS
    api-security.md           -- REST, GraphQL, rate limiting
    infrastructure.md         -- Headers, CORS, CSP, cookies
    supply-chain.md           -- Dependencies, typosquatting, SBOMs
    cloud-config.md           -- AWS/Azure/GCP misconfigurations
```

## Formato por categoría

```markdown
# Injection — Security Skill

## Vectores de ataque
- SQL Injection (union, blind, time-based, error-based)
- NoSQL Injection (MongoDB operators, JSON injection)
- OS Command Injection (pipes, backticks, $())
- LDAP Injection

## Patrones de detección
- Source: user input (query params, headers, body, cookies)
- Sink: database query, system call, LDAP query
- Sanitization check: parameterized queries, prepared statements

## Por lenguaje
| Lenguaje | ORM seguro | Patrón inseguro |
|----------|-----------|----------------|
| C#/EF | `.Where(x => x.Id == id)` | `$"SELECT * WHERE id = {id}"` |
| Java/JPA | `@Query` con `?1` | String concatenation en JPQL |
| Python/SQLAlchemy | `filter_by(id=id)` | f-string en `text()` |
| Node/Prisma | `prisma.user.findUnique()` | Raw query con template literal |

## Checklist de verificación
- [ ] Todas las queries usan parámetros vinculados
- [ ] Input validation en boundaries (controllers)
- [ ] No hay eval/exec con input del usuario
- [ ] Logging no incluye payloads del usuario sin sanitizar
```

## Protocolo de carga

Al iniciar un scan de seguridad:

1. Detectar stack del proyecto (Language Pack)
2. Detectar tipo de aplicación (web API, SPA, mobile backend, CLI)
3. Seleccionar categories relevantes:

| Tipo de app | Categories a cargar |
|-------------|-------------------|
| Web API REST | injection, authentication, access-control, api-security, infrastructure |
| SPA + API | xss, injection, authentication, access-control, api-security |
| Mobile backend | authentication, api-security, cryptography, access-control |
| Microservicios | injection, api-security, infrastructure, cloud-config |
| CLI/scripts | injection, supply-chain |

4. Max 5 categories por sesión (límite de contexto)
5. Categories se cargan como contexto adicional del agente

## Integración con agentes

```yaml
# En el prompt del security-attacker:
# Antes: conocimiento generico embebido (~3000 tokens)
# Después: skill index (~200 tokens) + categories relevantes (~1500 tokens)
# Ahorro: ~1300 tokens + mayor precisión por relevancia
```

El agente recibe:
- SKILL.md (índice, ~200 tokens)
- 3-5 categories seleccionadas (~300 tokens cada una)
- Total: ~1700 tokens vs ~3000 tokens actuales

## Métricas de éxito

- Detection rate en benchmarks (SPEC-032): mejora >= 5%
- False positive rate: reducción >= 10%
- Tokens por scan: reducción >= 30%

## Evolución

Las categories se enriquecen con hallazgos reales:
- Cada vuln encontrada en un proyecto real añade un patrón al skill
- Patrón de public-agent-memory: conocimiento genérico, en git
- Review trimestral para podar patrones obsoletos

## Esfuerzo estimado

Medio — 1 sprint. Extraer conocimiento existente, estructurar en 10
categories, adaptar prompts de agentes, verificar con benchmarks.

## Dependencias

- SPEC-032 (Benchmarks) para medir impacto
- agent-context-budget.md para respetar límites de tokens
