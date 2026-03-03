---
name: arch-recommend
description: Recomendar la mejor arquitectura para un proyecto nuevo
developer_type: all
agent: architect
context_cost: medium
---

# /arch-recommend {requirements}

> Recomienda el patrón de arquitectura óptimo para un proyecto nuevo basándose en sus requisitos.

---

## Prerequisitos

- Descripción del proyecto o requisitos

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Architecture & Debt** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar profundidad del análisis según `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Parámetros

- `{requirements}` — Descripción libre: tipo de app, lenguaje, escala, equipo, etc.

## 4. Flujo de Ejecución

### 1. Extraer Requisitos

Del input del usuario, identificar:
- **Tipo de aplicación**: API REST, web app, mobile, batch, IoT, etc.
- **Lenguaje/framework**: Si ya decidido
- **Escala esperada**: Usuarios, requests/s, datos
- **Tamaño del equipo**: 1-3, 4-10, 10+
- **Complejidad del dominio**: Simple (CRUD), Media, Compleja (DDD)
- **Requisitos especiales**: Real-time, offline, multi-tenant, compliance

Si faltan datos críticos, preguntar antes de recomendar.

### 2. Algoritmo de Recomendación

Scoring por patrón basado en requisitos:

| Factor | Clean | Hexagonal | DDD | CQRS | MVC | Microservices |
|--------|-------|-----------|-----|------|-----|---------------|
| CRUD simple | 30 | 20 | 10 | 10 | 90 | 10 |
| Dominio complejo | 80 | 85 | 95 | 70 | 30 | 60 |
| Alta testabilidad | 90 | 95 | 80 | 75 | 40 | 70 |
| Equipo pequeño | 70 | 60 | 40 | 30 | 90 | 20 |
| Equipo grande | 80 | 80 | 90 | 85 | 50 | 95 |
| Escala alta | 60 | 65 | 70 | 90 | 40 | 95 |
| Reads >> Writes | 50 | 50 | 60 | 95 | 50 | 70 |
| Real-time | 50 | 60 | 60 | 70 | 40 | 80 |
| Prototipo/MVP | 20 | 15 | 10 | 5 | 95 | 5 |

### 3. Cargar Reference del Lenguaje

Cargar el patrón de arquitectura del lenguaje detectado (si existe en references/)
Adaptar recomendación al lenguaje del framework.

### 4. Generar Reporte

```markdown
# 🎯 Architecture Recommendation — {proyecto}

**Requisitos**: {resumen}
**Fecha**: {fecha}

## Patrón Recomendado: {nombre}

### ¿Por qué este patrón?
{justificación basada en requisitos del proyecto}

### ¿Cuándo NO usar este patrón?
{limitaciones y riesgos}

### Folder Structure Propuesta
{tree adaptado al lenguaje}

### Dependencias Sugeridas
| Dependencia | Propósito |
|-------------|-----------|
| {nombre} | {para qué} |

### Alternativa Considerada: {nombre}
{por qué no se eligió, cuándo cambiar}

## 📋 ADR Draft

**ADR-XXX: Arquitectura {nombre} para {proyecto}**

**Status**: Proposed
**Context**: {requisitos del proyecto}
**Decision**: Usar {patrón} porque {razones}
**Consequences**: {positivas y negativas}
```

Output: `output/architecture/{proyecto}-recommendation.md`

## Post-ejecución

- Sugerir crear ADR con `/adr-create`
- Sugerir usar `/project-kickoff` con la estructura propuesta
- Si el usuario acepta, ofrecer generar scaffold del proyecto
