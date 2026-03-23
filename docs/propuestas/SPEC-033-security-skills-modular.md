# SPEC-033: Security Skills Modulares

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.30
> Origen: Analisis de usestrix/strix — 10 categorias de skills de seguridad
> Impacto: Mejora precision de agentes cargando conocimiento relevante

---

## Problema

Nuestros agentes de seguridad (security-attacker, pentester) tienen su
conocimiento embebido en el prompt del agente. Todo el conocimiento se
carga siempre, independientemente del tipo de aplicacion o vulnerabilidad.

Strix tiene 10 categorias de skills que se cargan dinamicamente (max 5
por sesion) segun el contexto del target. Esto reduce ruido y mejora
precision.

## Solucion

Extraer el conocimiento de seguridad a skills modulares que se carguen
segun el stack tecnologico y tipo de aplicacion del proyecto.

## Catalogo de skills de seguridad

```
.claude/skills/security-testing/
  SKILL.md                    -- Indice y protocolo de carga
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

## Formato por categoria

```markdown
# Injection — Security Skill

## Vectores de ataque
- SQL Injection (union, blind, time-based, error-based)
- NoSQL Injection (MongoDB operators, JSON injection)
- OS Command Injection (pipes, backticks, $())
- LDAP Injection

## Patrones de deteccion
- Source: user input (query params, headers, body, cookies)
- Sink: database query, system call, LDAP query
- Sanitization check: parameterized queries, prepared statements

## Por lenguaje
| Lenguaje | ORM seguro | Patron inseguro |
|----------|-----------|----------------|
| C#/EF | `.Where(x => x.Id == id)` | `$"SELECT * WHERE id = {id}"` |
| Java/JPA | `@Query` con `?1` | String concatenation en JPQL |
| Python/SQLAlchemy | `filter_by(id=id)` | f-string en `text()` |
| Node/Prisma | `prisma.user.findUnique()` | Raw query con template literal |

## Checklist de verificacion
- [ ] Todas las queries usan parametros vinculados
- [ ] Input validation en boundaries (controllers)
- [ ] No hay eval/exec con input del usuario
- [ ] Logging no incluye payloads del usuario sin sanitizar
```

## Protocolo de carga

Al iniciar un scan de seguridad:

1. Detectar stack del proyecto (Language Pack)
2. Detectar tipo de aplicacion (web API, SPA, mobile backend, CLI)
3. Seleccionar categories relevantes:

| Tipo de app | Categories a cargar |
|-------------|-------------------|
| Web API REST | injection, authentication, access-control, api-security, infrastructure |
| SPA + API | xss, injection, authentication, access-control, api-security |
| Mobile backend | authentication, api-security, cryptography, access-control |
| Microservicios | injection, api-security, infrastructure, cloud-config |
| CLI/scripts | injection, supply-chain |

4. Max 5 categories por sesion (limite de contexto)
5. Categories se cargan como contexto adicional del agente

## Integracion con agentes

```yaml
# En el prompt del security-attacker:
# Antes: conocimiento generico embebido (~3000 tokens)
# Despues: skill index (~200 tokens) + categories relevantes (~1500 tokens)
# Ahorro: ~1300 tokens + mayor precision por relevancia
```

El agente recibe:
- SKILL.md (indice, ~200 tokens)
- 3-5 categories seleccionadas (~300 tokens cada una)
- Total: ~1700 tokens vs ~3000 tokens actuales

## Metricas de exito

- Detection rate en benchmarks (SPEC-032): mejora >= 5%
- False positive rate: reduccion >= 10%
- Tokens por scan: reduccion >= 30%

## Evolucion

Las categories se enriquecen con hallazgos reales:
- Cada vuln encontrada en un proyecto real anade un patron al skill
- Patron de public-agent-memory: conocimiento generico, en git
- Review trimestral para podar patrones obsoletos

## Esfuerzo estimado

Medio — 1 sprint. Extraer conocimiento existente, estructurar en 10
categories, adaptar prompts de agentes, verificar con benchmarks.

## Dependencias

- SPEC-032 (Benchmarks) para medir impacto
- agent-context-budget.md para respetar limites de tokens
