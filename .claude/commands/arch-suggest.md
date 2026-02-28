---
name: arch-suggest
description: Sugerir mejoras de arquitectura basadas en detección previa
developer_type: all
agent: architect
context_cost: medium
---

# /arch-suggest {repo|path}

> Analiza un proyecto y genera sugerencias priorizadas de mejora arquitectónica.

---

## Prerequisitos

- Ejecutar `/arch-detect` primero (o se ejecutará automáticamente)
- Acceso al repositorio

## Parámetros

- `{repo|path}` — Ruta local o nombre del repositorio

## Flujo de Ejecución

### 1. Cargar detección previa

Si existe `output/architecture/{proyecto}-detection.md`, leerlo.
Si no existe, ejecutar `/arch-detect` primero.

### 2. Analizar violaciones

Para cada violación del reporte de detección:
- Clasificar severidad: CRITICAL (rompe el patrón) vs WARNING (desvío menor)
- Identificar ficheros afectados
- Proponer solución concreta con ejemplo

### 3. Identificar oportunidades de refactoring

Buscar:
- **God classes/modules**: ficheros >300 líneas con múltiples responsabilidades
- **Dependencias inversas**: módulos de bajo nivel usados por alto nivel
- **Código duplicado**: patrones repetidos que deberían ser abstracciones
- **Missing abstractions**: implementaciones directas sin interfaces/traits
- **Tight coupling**: clases que instancian dependencias (new) en lugar de recibirlas

### 4. Priorizar por impacto × esfuerzo

Matriz de priorización:

| | Esfuerzo Bajo | Esfuerzo Alto |
|---|---|---|
| **Impacto Alto** | 🟢 Quick Win | 🟡 Proyecto |
| **Impacto Bajo** | 🔵 Nice to have | ⚪ Postpone |

### 5. Generar Reporte

```markdown
# 🔍 Architecture Suggestions — {proyecto}

**Patrón Detectado**: {nombre} ({score}%)
**Fecha**: {fecha}

## 🟢 Quick Wins (alto impacto, bajo esfuerzo)
1. **{título}** — {descripción}
   - Ficheros: {lista}
   - Acción: {qué hacer}
   - Ejemplo: {antes → después}

## 🟡 Proyectos (alto impacto, alto esfuerzo)
1. **{título}** — {descripción}
   - Estimación: {horas}
   - Beneficio: {qué mejora}

## 🔵 Nice to Have
1. **{título}** — {descripción}

## ⚠️ Violaciones Críticas a Resolver
1. **{violación}**
   - Severidad: CRITICAL
   - Impacto: {qué rompe}
   - Solución: {cómo arreglarlo}

## 📊 Métricas de Salud Arquitectónica
| Métrica | Valor | Target |
|---------|-------|--------|
| Adherencia al patrón | {n}% | >80% |
| Dependencias inversas | {n} | 0 |
| Ficheros >300 líneas | {n} | 0 |
| Coupling index | {n} | <0.3 |
```

Output: `output/architecture/{proyecto}-suggestions.md`

## Post-ejecución

- Si hay violaciones CRITICAL → sugerir crear tasks en Azure DevOps
- Sugerir `/arch-fitness` para prevenir regresiones
- Sugerir `/adr-create` para documentar decisiones de refactoring
