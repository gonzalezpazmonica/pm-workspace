---
name: arch-compare
description: Comparar dos patrones de arquitectura para toma de decisiones
developer_type: all
agent: architect
context_cost: low
---

# /arch-compare {pattern1} {pattern2}

> Genera una comparativa detallada entre dos patrones de arquitectura.

---

## Prerequisitos

- Ninguno

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Architecture & Debt** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar profundidad del análisis según `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Parámetros

- `{pattern1}` — Primer patrón (clean, hexagonal, ddd, cqrs, mvc, mvvm, microservices, event-driven)
- `{pattern2}` — Segundo patrón
- `--context {description}` — (Opcional) Contexto del proyecto para personalizar

## 4. Patrones Reconocidos

| Alias | Patrón |
|-------|--------|
| clean | Clean Architecture |
| hexagonal, ports-adapters | Hexagonal (Ports & Adapters) |
| ddd | Domain-Driven Design |
| cqrs | CQRS (+ Event Sourcing) |
| mvc | MVC / MVT |
| mvvm | MVVM / MVP |
| microservices, micro | Microservices |
| event-driven, eda | Event-Driven Architecture |
| layered | Layered (N-Tier) |
| monolith | Modular Monolith |

## 5. Flujo de Ejecución

### 1. Validar Patrones

Verificar que ambos patrones son reconocidos. Si no, sugerir el más cercano.

### 2. Generar Comparativa

```markdown
# ⚖️ {Pattern1} vs {Pattern2}

**Fecha**: {fecha}
{si hay contexto: **Contexto**: {descripción}}

## Tabla Comparativa

| Dimensión | {Pattern1} | {Pattern2} |
|-----------|------------|------------|
| **Complejidad inicial** | {Baja/Media/Alta} | {Baja/Media/Alta} |
| **Curva de aprendizaje** | {descripción} | {descripción} |
| **Testabilidad** | {⭐⭐⭐⭐⭐} | {⭐⭐⭐⭐⭐} |
| **Escalabilidad** | {descripción} | {descripción} |
| **Mantenibilidad** | {descripción} | {descripción} |
| **Equipo mínimo** | {n personas} | {n personas} |
| **Ideal para** | {tipo de proyecto} | {tipo de proyecto} |
| **NO usar para** | {tipo de proyecto} | {tipo de proyecto} |
| **Frameworks populares** | {lista} | {lista} |
| **Herramientas de enforcement** | {lista} | {lista} |

## {Pattern1} — Pros y Contras

### ✅ Ventajas
- {ventaja con explicación}

### ❌ Desventajas
- {desventaja con explicación}

## {Pattern2} — Pros y Contras

### ✅ Ventajas
- {ventaja con explicación}

### ❌ Desventajas
- {desventaja con explicación}

## ¿Cuándo elegir cada uno?

**Elige {Pattern1} si**: {condiciones}
**Elige {Pattern2} si**: {condiciones}
**Combínalos si**: {condiciones donde ambos aportan}

## Migración entre patrones

{Es posible migrar de uno a otro? Cómo? Esfuerzo estimado?}
```

### 3. Personalizar por contexto

Si el usuario proporcionó `--context`:
- Añadir sección "Recomendación para tu caso" con scoring
- Indicar cuál patrón se adapta mejor al contexto dado

Output: se muestra en consola (no genera fichero salvo que se pida)

## Post-ejecución

- Sugerir `/arch-recommend` para recomendación formal
- Sugerir `/adr-create` para documentar la decisión
