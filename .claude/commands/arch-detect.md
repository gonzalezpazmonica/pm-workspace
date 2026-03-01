---
name: arch-detect
description: Detectar el patrón de arquitectura de un repositorio o proyecto
developer_type: all
agent: architect
context_cost: medium
---

# /arch-detect {repo|path}

> Analiza un repositorio o path local para identificar qué patrón de arquitectura sigue.

---

## Prerequisitos

- Repositorio accesible (local o URL clonable)
- Si es Azure DevOps: PAT configurado

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Architecture & Debt** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar profundidad del análisis según `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Parámetros

- `{repo|path}` — Ruta local o nombre del repositorio en Azure DevOps

## 4. Flujo de Ejecución

### 1. Identificar lenguaje y framework

Detectar por extensiones, `package.json`, `pom.xml`, `*.csproj`, `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json`, `pubspec.yaml`, etc.

Cargar reference correspondiente: `@.claude/skills/architecture-intelligence/references/patterns-{lang}.md`

### 2. Fase 1 — Análisis de Estructura (40%)

Listar carpetas del proyecto y comparar con patrones conocidos del lenguaje.

Para cada patrón, calcular match de carpetas:
- `score_estructura = carpetas_encontradas / carpetas_esperadas × 100`

### 3. Fase 2 — Análisis de Dependencias (30%)

Buscar imports/using/require entre módulos:
- ¿Domain importa Infrastructure? → violación Clean/Hexagonal
- ¿Hay dependencias circulares? → violación cualquier patrón
- ¿Hay bus de comandos/eventos? → indicador CQRS/EDA

`score_dependencias = reglas_cumplidas / reglas_totales × 100`

### 4. Fase 3 — Análisis de Naming (20%)

Buscar sufijos indicativos en nombres de ficheros y clases:
- Controller, Service, Repository, UseCase, Command, Query, Handler
- Port, Adapter, Aggregate, ValueObject, DomainEvent, ViewModel

`score_naming = indicadores_encontrados / indicadores_esperados × 100`

### 5. Fase 4 — Análisis de Config (10%)

Buscar ficheros de configuración indicativos:
- docker-compose.yml, DI config, event bus config, API gateway

`score_config = configs_encontradas / configs_esperadas × 100`

### 6. Calcular Score Final

Para cada patrón candidato:
`score_total = (estructura × 0.4) + (dependencias × 0.3) + (naming × 0.2) + (config × 0.1)`

### 7. Generar Reporte

```markdown
# 🏗️ Architecture Detection — {proyecto}

**Lenguaje**: {lang} · **Framework**: {framework}
**Fecha**: {fecha}

## Patrón Principal: {nombre} — Score: {score}%
**Nivel de Adherencia**: {Alto|Medio|Bajo}

### Evidencia
| Fase | Score | Detalle |
|------|-------|---------|
| Estructura | {n}% | {carpetas encontradas} |
| Dependencias | {n}% | {reglas cumplidas/violadas} |
| Naming | {n}% | {indicadores encontrados} |
| Configuración | {n}% | {configs encontradas} |

### Violaciones Detectadas
1. ⚠️ {violación} — Severidad: {CRITICAL|WARNING}

### Patrones Secundarios
- {patrón}: {score}%

### Recomendación
{acción sugerida para mejorar adherencia}
```

Output: `output/architecture/{proyecto}-detection.md`

## Post-ejecución

- Sugerir `/arch-suggest` si hay violaciones
- Sugerir `/arch-fitness` para monitorización continua
- Si score <50%: advertir que el patrón no está bien definido
