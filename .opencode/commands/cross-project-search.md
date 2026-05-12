---
name: cross-project-search
description: Búsqueda transversal de conocimiento entre todos los proyectos del portfolio
developer_type: all
agent: task
context_cost: medium
---

# /cross-project-search

> 🦉 Savia busca en todos tus proyectos a la vez para que no reinventes la rueda.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar:

- `identity.md` — slug (para aislar búsquedas)

---

## Subcomandos

- `/cross-project-search {query}` — buscar en todos los proyectos
- `/cross-project-search {query} --type code` — solo código fuente
- `/cross-project-search {query} --type docs` — solo documentación
- `/cross-project-search {query} --type specs` — solo specs SDD
- `/cross-project-search {query} --type decisions` — solo ADRs y decisiones

---

## Flujo

### Paso 1 — Determinar alcance de búsqueda

1. Listar todos los proyectos en `projects/`
2. Filtrar por proyectos con source clonado (si --type code)
3. Filtrar por proyectos con specs/ (si --type specs)

### Paso 2 — Ejecutar búsqueda por proyecto

Para cada proyecto, buscar `{query}` en:

- **code**: `projects/{p}/source/` — grep en ficheros fuente
- **docs**: `projects/{p}/*.md` + `docs/` — documentación
- **specs**: `projects/{p}/specs/` — specs SDD
- **decisions**: `projects/{p}/adrs/` + memoria persistente

### Paso 3 — Consolidar y presentar resultados

```
🔍 Cross-Project Search: "{query}"

  📁 proyecto-A (3 resultados)
    - src/Services/AuthService.cs:42 — implementación OAuth2
    - specs/Sprint-05/AB1234-auth-handler.spec.md — spec del handler
    - adrs/ADR-007-auth-strategy.md — decisión arquitectónica

  📁 proyecto-B (1 resultado)
    - docs/security-guidelines.md:15 — guía de autenticación

  📁 proyecto-C (0 resultados)

  Total: 4 resultados en 2 proyectos
```

### Paso 4 — Sugerencias de reutilización

Si la búsqueda encuentra implementaciones similares en múltiples proyectos:

```
💡 Reutilización detectada
  "AuthService" existe en proyecto-A y proyecto-B con 73% similitud.
  Considerar: extraer a librería compartida o documentar como patrón.
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: cross_project_search
query: "OAuth2"
projects_searched: 3
total_results: 4
projects_with_results: 2
reuse_candidates: 1
```

---

## Restricciones

- **NUNCA** mostrar credenciales, tokens o datos sensibles encontrados
- **NUNCA** buscar en `config.local/` o ficheros git-ignorados
- Limitar resultados a 10 por proyecto para no saturar
- Si no hay source clonado → indicar y sugerir clonar
