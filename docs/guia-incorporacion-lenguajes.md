# Guía de Incorporación de Lenguajes a PM-Workspace

> **Audiencia:** Claude Opus (agente PM) o cualquier operador que necesite añadir soporte para un nuevo lenguaje/framework.
> **Prerequisito:** Haber leído `CLAUDE.md`, `.claude/rules/pm-config.md` y `.claude/rules/pm-workflow.md`.
> **Última actualización:** 2026-02-26

---

## Concepto: Language Pack

Cada lenguaje se incorpora mediante un **Language Pack**: un conjunto de ficheros que encapsulan todo lo específico del stack técnico. La capa de gestión de proyectos (Scrum, Azure DevOps, capacity, reporting) permanece intacta.

```
Language Pack = conventions.md + rules.md + developer agent + layer assignment matrix
```

---

## Paso 0 — Evaluar la necesidad

Antes de crear un Language Pack, verificar:

1. ¿El lenguaje tiene demanda real en los proyectos gestionados?
2. ¿Existe ya un Language Pack similar que pueda reutilizarse? (ej: VB.NET → reutilizar dotnet-conventions.md)
3. ¿El lenguaje tiene tooling de CLI suficiente para automatizar build/test/lint?

Si la respuesta a las tres es "sí", proceder.

---

## Paso 1 — Crear {lang}-conventions.md

**Ubicación:** `.claude/rules/{lang}-conventions.md`
**Referencia:** `.claude/rules/dotnet-conventions.md`

### Estructura obligatoria

```markdown
# Regla: Convenciones y Prácticas {Lenguaje/Framework}
# ── Aplica a todos los proyectos {lang} en este workspace ──

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

​```bash
{build_command}                    # 1. ¿Compila/transpila sin errores?
{format_command}                   # 2. ¿Respeta el estilo del proyecto?
{lint_command}                     # 3. ¿Pasa el linter sin warnings?
{test_unit_command}                # 4. ¿Pasan los tests unitarios?
​```

Si hay tests de integración relevantes al cambio:
​```bash
{test_integration_command}
​```

## Convenciones de código {Lenguaje}

- **Naming:** {convenciones de naming del lenguaje}
- **Async/concurrencia:** {patrón async del lenguaje}
- **Error handling:** {patrón de errores del lenguaje}
- **DI/IoC:** {inyección de dependencias}
- **Inmutabilidad:** {records, data classes, etc.}

## {ORM/Acceso a datos del lenguaje}

- {Convenciones de ORM}
- {Migraciones}
- {Queries y performance}

## Tests

- Tests unitarios en: `{ruta}`
- Tests de integración en: `{ruta}`
- Framework: {jest, pytest, junit, etc.}
- Naming: `MetodoObjeto_Escenario_ResultadoEsperado`
- Categorización: {cómo separar unit/integration}

## Gestión de dependencias

​```bash
{list_outdated_command}              # ver paquetes obsoletos
{add_package_command}                # añadir con versión explícita
{audit_command}                      # detectar vulnerabilidades
​```

## Estructura de solución

​```
{estructura de carpetas del proyecto tipo}
​```

## Deploy

​```bash
{build_production_command}
{deploy_command}
​```

## Hooks recomendados para proyectos {lang}

​```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "{build_check_command}"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "{test_command}"
    }]
  }
}
​```
```

### Criterios de calidad

- [ ] Todos los comandos son ejecutables en CLI sin interacción
- [ ] Las convenciones de naming son específicas y sin ambigüedad
- [ ] La estructura de proyecto refleja la arquitectura real del framework
- [ ] Los hooks incluyen build y test automáticos
- [ ] Se documenta cómo verificar vulnerabilidades en dependencias

---

## Paso 2 — Crear {lang}-rules.md

**Ubicación:** `.claude/rules/{lang}-rules.md`
**Referencia:** `.claude/rules/csharp-rules.md`

### Estructura obligatoria

Organizar por severidad, siguiendo el patrón SonarQube:

```markdown
# Reglas de Análisis Estático {Lenguaje} — Knowledge Base para Agente de Revisión

## Instrucciones para el Agente

Protocolo de reporte idéntico a csharp-rules.md:
- ID de regla, Severidad, Línea(s), Descripción, Sugerencia con código
- Priorización: Vulnerabilities → Bugs → Code Smells

## 1. VULNERABILITIES — Seguridad

### 1.1 Blocker
{Credenciales hardcodeadas, inyecciones, XXE, secrets expuestos}

### 1.2 Critical
{Crypto débil, TLS, hashing, deserialización}

### 1.3 Major
{CORS, CSRF, deserialización sin restricción}

## 2. SECURITY HOTSPOTS

{PRNG, SQL injection, regex DoS, protocolos cleartext}

## 3. BUGS

### 3.1 Blocker
{Null/undefined dereference, memory leaks, infinite loops}

### 3.2 Critical
{Race conditions, async void, resource leaks}

### 3.3 Major
{Type coercion, unused awaits, wrong comparisons}

## 4. CODE SMELLS

### 4.1 Critical
{Complejidad cognitiva > 15, dead code en paths críticos}

### 4.2 Major
{Variables no usadas, código comentado, duplicación}

## 5. REGLAS DE ARQUITECTURA

{Equivalentes a ARCH-01..ARCH-12, adaptados al framework}
```

### Criterios de calidad

- [ ] Cada regla tiene ejemplo ❌ incorrecto y ✅ correcto
- [ ] Las severidades están correctamente asignadas
- [ ] Las reglas de arquitectura reflejan la separación de capas del framework
- [ ] Se incluyen IDs de regla (SonarQube, ESLint, Clippy, etc.) cuando existen

### Nota para lenguajes legacy (COBOL, VB6)

Si el lenguaje no tiene tooling de análisis estático moderno, documentar:
- Reglas manuales de revisión equivalentes
- Patrones peligrosos conocidos del lenguaje
- Herramientas disponibles (aunque sean limitadas)

---

## Paso 3 — Crear {lang}-developer.md (Agente)

**Ubicación:** `.claude/agents/{lang}-developer.md`
**Referencia:** `.claude/agents/dotnet-developer.md`

### Estructura obligatoria

```markdown
# Agente: {lang}-developer

> Desarrollador senior {Lenguaje}/{Framework}. Implementa Specs SDD siguiendo las convenciones del proyecto.

## Configuración

- **Modelo:** claude-sonnet-4-6
- **Max turns:** 30
- **Herramientas:** Read, Write, Edit, Bash, Glob, Grep

## Instrucciones

### Rol
Eres un desarrollador senior especializado en {Lenguaje} con {Framework}.
Tu trabajo es implementar Specs SDD exactamente como se describen.

### Reglas de implementación

1. **Leer SIEMPRE** la Spec completa antes de escribir código
2. **Leer SIEMPRE** `{lang}-conventions.md` antes de implementar
3. **Seguir el patrón** del código de referencia (sección 7 de la Spec)
4. **Ejecutar** `{build_command}` tras cada cambio significativo
5. **Ejecutar** `{test_command}` al finalizar
6. **Si la Spec es ambigua**, documentar la duda en la Spec y DETENERSE
7. **Nunca tomar decisiones de diseño** que no estén en la Spec

### Verificación al completar

​```bash
{build_command}
{format_command}
{lint_command}
{test_unit_command}
​```

Los 4 comandos deben pasar sin errores ni warnings.

### Convenciones específicas

- Naming: {resumen de convenciones del lenguaje}
- Arquitectura: {capas del framework}
- Testing: {framework y convenciones}
- Error handling: {patrón del lenguaje}

### Anti-patterns a evitar

1. {anti-pattern específico del lenguaje}
2. {otro anti-pattern}
3. Nunca añadir dependencias sin que estén en la Spec
4. Nunca generar código fuera de los ficheros listados en la Spec
```

### Criterios de calidad

- [ ] El agente sabe qué comandos ejecutar para verificar su trabajo
- [ ] Las convenciones son lo suficientemente específicas para evitar ambigüedad
- [ ] Los anti-patterns cubren los errores más comunes del lenguaje
- [ ] El modelo asignado es apropiado (Sonnet para implementación, Opus para arquitectura)

---

## Paso 4 — Crear layer-assignment-matrix-{lang}.md

**Ubicación:** `.claude/skills/spec-driven-development/references/layer-assignment-matrix-{lang}.md`
**Referencia:** `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md`

### Estructura obligatoria

```markdown
# Layer Assignment Matrix — {Lenguaje}/{Framework}

> Matrix de asignación human vs agent para proyectos {Framework}.

## Principio General

Capas que favorecen `agent`:  Código estructural, repetitivo, con patrón claro
Capas que favorecen `human`:  Lógica de dominio, decisiones de arquitectura, integraciones

## Matrix por Capa

### {Capa 1 — equivalente a Domain}

| Tipo de Tarea | Developer Type | Justificación |
|---|---|---|
| ... | ... | ... |

### {Capa 2 — equivalente a Application}
### {Capa 3 — equivalente a Infrastructure}
### {Capa 4 — equivalente a API/Presentation}
### Tests

## Heurísticas de Decisión Rápida

(Mismas que la matrix original, adaptadas al lenguaje)

## Impacto Esperado

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|---|---|---|---|
| ... | ... | ... | ... |
```

### Mapeo de capas por framework

| Framework | Domain | Application | Infrastructure | Presentation |
|---|---|---|---|---|
| ASP.NET Core | Domain/ | Application/ | Infrastructure/ | API/ |
| Spring Boot | domain/ | application/ | infrastructure/ | adapter/web/ |
| FastAPI | domain/ | application/ | infrastructure/ | api/ |
| NestJS | domain/ | application/ | infrastructure/ | controllers/ |
| Angular | — | services/ | — | components/ |
| React | — | hooks/ | api/ | components/ |
| Go (Clean) | domain/ | usecase/ | repository/ | handler/ |
| Rust (Axum) | domain/ | application/ | infrastructure/ | api/ |
| Laravel | Domain/ | Application/ | Infrastructure/ | Http/ |
| Rails | models/ | services/ | — | controllers/ |

---

## Paso 5 — Crear proyecto de ejemplo

**Ubicación:** `projects/{nombre-ejemplo}/`
**Referencia:** `projects/sala-reservas/`

### Estructura mínima

```
projects/{nombre-ejemplo}/
├── CLAUDE.md                    # Config del proyecto
├── equipo.md                    # Equipo ficticio
├── reglas-negocio.md           # Reglas de negocio del ejemplo
├── source/                     # Código fuente
│   └── {estructura del framework}
├── specs/
│   └── sprint-{actual}/
│       └── {spec de ejemplo}.spec.md
├── sprints/
│   └── sprint-{actual}/
│       └── planning.md
└── test-data/                  # Mock data para tests sin Azure DevOps
    ├── mock-workitems.json
    ├── mock-sprint.json
    └── mock-capacities.json
```

### CLAUDE.md del proyecto debe incluir

```markdown
# Stack del proyecto
LANGUAGE_PACK       = "{lang}"
FRAMEWORK           = "{framework}"
DEVELOPER_AGENT     = "{lang}-developer"
BUILD_COMMAND       = "{build_command}"
TEST_COMMAND        = "{test_command}"
LINT_COMMAND        = "{lint_command}"
FORMAT_COMMAND      = "{format_command}"
```

---

## Paso 6 — Registrar en el workspace

### 6.1 Actualizar CLAUDE.md raíz

Añadir el nuevo Language Pack a la tabla de Language Packs en `CLAUDE.md`:

```markdown
| {Lenguaje} | {lang}-conventions.md | {lang}-rules.md | {lang}-developer | ✅ |
```

### 6.2 Actualizar README.md

Añadir el lenguaje a la sección "Lenguajes Soportados" en `README.md` y `README.en.md`.

### 6.3 Actualizar CHANGELOG.md

```markdown
### Added
- Language Pack: {Lenguaje}/{Framework} — conventions, rules, agent, layer matrix
```

---

## Paso 7 — Validar

### Checklist de validación

- [ ] `{lang}-conventions.md` existe y tiene todas las secciones obligatorias
- [ ] `{lang}-rules.md` existe con reglas organizadas por severidad
- [ ] `{lang}-developer.md` existe con comandos de verificación correctos
- [ ] `layer-assignment-matrix-{lang}.md` existe con todas las capas
- [ ] Los comandos de build/test/lint/format son ejecutables en CLI
- [ ] La estructura de proyecto es realista para el framework
- [ ] Se ha probado con al menos un proyecto de ejemplo
- [ ] CLAUDE.md raíz actualizado
- [ ] README.md actualizado

---

## Referencia Rápida: Detección Automática de Lenguaje

Para el comando `/context:load`, detectar el Language Pack automáticamente:

| Archivo(s) en el proyecto | Language Pack |
|---|---|
| `*.csproj`, `*.sln`, `*.slnx` | `dotnet` |
| `package.json` + `angular.json` | `angular` |
| `package.json` + `next.config.*` | `react` (Next.js) |
| `package.json` + `vite.config.*` + `*.tsx` | `react` (Vite) |
| `package.json` + `vite.config.*` (sin tsx) | `typescript` |
| `package.json` (sin framework frontend) | `typescript` (Node.js) |
| `pom.xml` | `java` (Maven) |
| `build.gradle.kts` (sin Android) | `java` (Gradle) |
| `build.gradle.kts` + `*Activity.kt` | `kotlin` (Android) |
| `requirements.txt`, `pyproject.toml`, `setup.py` | `python` |
| `go.mod` | `go` |
| `Cargo.toml` | `rust` |
| `composer.json` | `php` |
| `Gemfile` | `ruby` |
| `*.xcodeproj`, `Package.swift` | `swift` |
| `pubspec.yaml` | `flutter` |
| `*.tf`, `*.tfvars` | `terraform` |
| `*.cob`, `*.cbl` | `cobol` |
| `*.vb` + `*.vbproj` | `vbnet` |

---

## Language Packs Existentes

| Lenguaje | Conventions | Rules | Agent | Layer Matrix | Estado |
|---|---|---|---|---|---|
| C#/.NET | `dotnet-conventions.md` | `csharp-rules.md` | `dotnet-developer` | `layer-assignment-matrix.md` | ✅ Producción |
| TypeScript/Node.js | `typescript-conventions.md` | `typescript-rules.md` | `typescript-developer` | `layer-assignment-matrix-typescript.md` | ✅ |
| Angular | `angular-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-angular.md` | ✅ |
| React | `react-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-react.md` | ✅ |
| Java/Spring | `java-conventions.md` | `java-rules.md` | `java-developer` | `layer-assignment-matrix-java.md` | ✅ |
| Python | `python-conventions.md` | `python-rules.md` | `python-developer` | `layer-assignment-matrix-python.md` | ✅ |
| Go | `go-conventions.md` | `go-rules.md` | `go-developer` | `layer-assignment-matrix-go.md` | ✅ |
| Rust | `rust-conventions.md` | `rust-rules.md` | `rust-developer` | `layer-assignment-matrix-rust.md` | ✅ |
| PHP/Laravel | `php-conventions.md` | `php-rules.md` | `php-developer` | `layer-assignment-matrix-php.md` | ✅ |
| Swift/iOS | `swift-conventions.md` | `swift-rules.md` | `mobile-developer` | `layer-assignment-matrix-swift.md` | ✅ |
| Kotlin/Android | `kotlin-conventions.md` | `kotlin-rules.md` | `mobile-developer` | `layer-assignment-matrix-kotlin.md` | ✅ |
| Ruby/Rails | `ruby-conventions.md` | `ruby-rules.md` | `ruby-developer` | `layer-assignment-matrix-ruby.md` | ✅ |
| VB.NET | `vbnet-conventions.md` | (usa csharp-rules) | `dotnet-developer` | (usa layer-assignment-matrix.md) | ✅ |
| COBOL | `cobol-conventions.md` | `cobol-rules.md` | `cobol-developer` | `layer-assignment-matrix-cobol.md` | ✅ |
| Terraform/IaC | `terraform-conventions.md` | `terraform-rules.md` | `terraform-developer` | `layer-assignment-matrix-terraform.md` | ✅ |
| Flutter/Dart | `flutter-conventions.md` | `flutter-rules.md` | `mobile-developer` | `layer-assignment-matrix-flutter.md` | ✅ |
