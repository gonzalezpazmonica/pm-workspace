---
name: code-patterns
description: Catálogo de patterns del proyecto con ejemplos del propio código del equipo
developer_type: all
agent: task
context_cost: high
---

# /code-patterns

> 🦉 Savia documenta los patterns de tu proyecto con ejemplos reales de tu código.

---

## Cargar perfil de usuario

Grupo: **Architecture & Debt** — cargar:

- `identity.md` — nombre, rol
- `projects.md` — proyecto target
- `preferences.md` — detail_level

---

## Subcomandos

- `/code-patterns` — catálogo completo de patterns detectados
- `/code-patterns {pattern}` — detalle de un pattern específico
- `/code-patterns --new` — patterns más recientes del sprint

---

## Flujo

### Paso 1 — Detectar patterns en el código

Analizar el código del proyecto buscando:

| Categoría | Patterns a detectar |
|---|---|
| Arquitecturales | Repository, Service, Controller, CQRS, Mediator |
| Creacionales | Factory, Builder, Singleton, DI registration |
| Estructurales | Adapter, Decorator, Facade, Proxy |
| Comportamiento | Strategy, Observer, Command, Chain |
| Resiliencia | Retry, Circuit Breaker, Fallback, Timeout |
| Testing | AAA, Builder, Mother, Fixture |

### Paso 2 — Extraer ejemplos reales

Para cada pattern detectado:

1. Encontrar la mejor implementación en el código del equipo
2. Extraer snippet representativo (máximo 20 líneas)
3. Identificar fichero y autor

### Paso 3 — Generar catálogo

```
🦉 Code Patterns — {proyecto}

📊 Patterns detectados: {N}

### Repository Pattern
  Usado en: {N} ficheros
  Ejemplo: `src/Repositories/UserRepository.cs`
  ```
  {snippet de 10-15 líneas}
  ```
  Convención del equipo: {descripción breve}

### Service Pattern
  Usado en: {N} ficheros
  Ejemplo: ...
```

### Paso 4 — Identificar patterns ausentes

Comparar con patterns recomendados para la arquitectura detectada.
Si faltan patterns esperados → sugerir adopción.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: code_patterns
project: sala-reservas
patterns_found: 12
categories:
  architectural: 4
  creational: 2
  structural: 3
  behavioral: 2
  testing: 1
missing_recommended: 2
```

---

## Restricciones

- **NUNCA** incluir snippets de más de 20 líneas
- **NUNCA** criticar código — solo documentar patterns
- Usar ejemplos del propio código, no ejemplos genéricos
- Respetar autoría — indicar quién escribió cada ejemplo
