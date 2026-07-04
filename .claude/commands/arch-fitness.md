---
name: arch-fitness
description: Ejecutar fitness functions de arquitectura para verificar integridad
developer_type: all
agent: architect
context_cost: medium
tier: extended
---

# /arch-fitness {repo|path}

> Define y ejecuta reglas de integridad arquitectónica (fitness functions) para un proyecto.

---

## Prerequisitos

- Repositorio accesible
- Recomendado: ejecutar `/arch-detect` primero

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Architecture & Debt** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar profundidad del análisis según `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Parámetros

- `{repo|path}` — Ruta local o repositorio
- `--rules {file}` — (Opcional) Fichero custom de reglas
- `--fix` — (Opcional) Sugerir fixes automáticos

## 4. Flujo de Ejecución

### 1. Detectar Patrón y Lenguaje

Si no hay detección previa, ejecutar detección rápida (solo estructura).
Cargar reglas base del patrón detectado.

### 2. Definir Reglas de Fitness

Reglas automáticas según patrón:

**Clean Architecture / Hexagonal**:
- CRITICAL: Domain NO importa Infrastructure
- CRITICAL: Domain NO importa Presentation
- WARNING: Application NO importa Presentation directamente
- WARNING: No dependencias circulares entre capas

**DDD**:
- CRITICAL: Aggregates solo accesibles via Repository
- WARNING: Value Objects son inmutables (no setters públicos)
- WARNING: Domain Events nombrados en pasado (OrderCreated, UserRegistered)

**MVC / MVVM**:
- WARNING: Controllers/ViewModels NO acceden a DB directamente
- WARNING: Views NO contienen lógica de negocio
- CRITICAL: Models NO dependen de Views

**Genéricas (todos los patrones)**:
- WARNING: No ficheros >300 líneas (configurable)
- WARNING: No más de 10 imports/dependencias por fichero
- CRITICAL: No secrets hardcodeados (regex patterns)
- WARNING: Naming conventions del patrón (sufijos esperados)

### 3. Ejecutar Análisis

Para cada regla:
1. Escanear ficheros relevantes
2. Buscar violaciones (imports, naming, estructura)
3. Clasificar: PASS / FAIL
4. Si FAIL: listar ficheros y líneas

### 4. Generar Reporte

```markdown
# 🏋️ Architecture Fitness — {proyecto}

**Patrón**: {nombre} · **Reglas ejecutadas**: {n}
**Fecha**: {fecha}

## Resultado Global: {PASS|FAIL} ({passed}/{total} reglas)

### ✅ Reglas PASS
1. ✅ Domain independence — Sin violaciones
2. ✅ No circular dependencies — Limpio

### ❌ Reglas FAIL
1. ❌ **Domain NO importa Infrastructure** — CRITICAL
   - `src/domain/UserService.ts` línea 3: `import { PrismaClient }`
   - `src/domain/OrderRepo.ts` línea 1: `import { db }`
   - **Fix**: Crear interface en domain, implementar en infrastructure

2. ❌ **File size limit** — WARNING
   - `src/controllers/MainController.ts`: 452 líneas (max: 300)
   - **Fix**: Dividir en controllers por recurso

### 📊 Resumen
| Severidad | Pass | Fail |
|-----------|------|------|
| CRITICAL | {n} | {n} |
| WARNING | {n} | {n} |

### 📈 Tendencia
{comparar con ejecución anterior si existe}
```

Output: `output/architecture/{proyecto}-fitness.md`

## Post-ejecución

- Si hay FAIL CRITICAL → recomendar resolución inmediata
- Sugerir integrar como check de CI (crear script verificador)
- Guardar resultado para comparación futura (tendencia)
