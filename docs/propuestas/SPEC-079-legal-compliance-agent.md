---
id: SPEC-079
title: SPEC-079 — Agente de Compliance Legal con legalize-es
status: PROPOSED
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-079 — Agente de Compliance Legal con legalize-es

> **Estado**: Propuesta
> **Fecha**: 2026-04-07
> **Tipo**: Agente + Skill + Integración de datos
> **Prioridad**: Alta — habilita auditoría legal transversal para todos los proyectos

---

## 1. Contexto y Objetivo

### Problema

Los proyectos de software manejan reglas de negocio, contratos, políticas de privacidad
y obligaciones regulatorias que deben cumplir la legislación española vigente. Actualmente,
verificar el cumplimiento legal requiere consulta manual a abogados o búsqueda ad-hoc
en el BOE. No existe un mecanismo automatizado que cruce las reglas del proyecto con
la legislación consolidada.

### Solución

Integrar el repositorio [legalize-es](https://github.com/legalize-dev/legalize-es)
(12.235 normas consolidadas, 17 CCAA, 43.046 commits de reformas) como fuente de verdad
legislativa. Crear un agente `legal-compliance` que audite proyectos, contratos,
reglas de negocio y documentos contra la legislación vigente.

### Fuente de datos

| Dimensión | Valor |
|-----------|-------|
| Repositorio | `legalize-dev/legalize-es` (MIT + dominio público) |
| Normas estatales | 8.646 en `es/` |
| Normas autonómicas | 3.589 en `es-{ccaa}/` (17 comunidades) |
| Formato | Markdown con frontmatter YAML |
| Versionado | Commits con fecha BOE real — historial completo de reformas |
| Actualización | Diaria desde API abierta del BOE |
| Identificador | ELI (European Legislation Identifier) por norma |

### Frontmatter de cada norma

```yaml
---
title: "Ley Orgánica 3/2018, de 5 de diciembre, de Protección de Datos..."
identifier: BOE-A-2018-16673
regulatory_rank: Ley Orgánica
publication_date: "2018-12-06"
legal_status: vigente
department: Jefatura del Estado
official_number: "3/2018"
eli: https://www.boe.es/eli/es/lo/2018/12/05/3/con
---
```

---

## 2. Alcance funcional

### 2.1. Tipos de auditoría

| Tipo | Input | Output | Ejemplo |
|------|-------|--------|---------|
| **Reglas de negocio** | `reglas-negocio.md` del proyecto | Mapping regla→artículo, gaps, conflictos | RN-001 vs LOPDGDD Art. 13 |
| **Contratos** | Documento contractual (DOCX/PDF/MD) | Cláusulas faltantes, plazos ilegales, nulidades | Contrato SaaS vs Ley 34/2002 LSSI |
| **Arquitectura** | `ARCHITECTURE.md`, specs | Requisitos técnicos legales no cubiertos | RGPD Art. 25 (privacy by design) |
| **Políticas** | Política de privacidad, cookies, EULA | Conformidad con legislación vigente | Política cookies vs LSSI Art. 22.2 |
| **PBIs/Features** | PBI description + acceptance criteria | Implicaciones legales del feature | Feature biométrico → LOPDGDD Art. 9 |
| **Documentos generales** | Cualquier documento del proyecto | Screening legal transversal | Acta de reunión con compromisos legales |

### 2.2. Dominios legales prioritarios

| Dominio | Normas clave | Vertical |
|---------|-------------|----------|
| Protección de datos | LOPDGDD (LO 3/2018), RGPD | Todas |
| Comercio electrónico | LSSI (Ley 34/2002) | SaaS, web, e-commerce |
| Propiedad intelectual | LPI (RDL 1/1996), Ley de Patentes | Software, contenidos |
| Laboral | Estatuto Trabajadores (RDL 2/2015), Ley Teletrabajo | RRHH, equipos |
| Consumidores | LGDCU (RDL 1/2007) | B2C, SaaS |
| Accesibilidad | RD 1112/2018 (accesibilidad web) | Web, apps |
| Ciberseguridad | RD 311/2022 (ENS), Ley NIS2 | Infra, seguridad |
| Facturación | Ley antifraude, Reglamento Verifactu | Fintech, ERP |
| IA | Reglamento IA UE + transposición ES | Agentes, ML |
| Sector financiero | Ley mercado valores, PSD2 | Fintech, banca |
| Sanidad | Ley 41/2002 (autonomía paciente), LSSICE | Healthcare |
| Educación | LOMLOE, FERPA-equiv ES | EdTech |

### 2.3. Fuera de alcance (v1)

- Jurisprudencia (sentencias de tribunales) — solo legislación
- Legislación de otros países (solo España + CCAA)
- Asesoramiento jurídico vinculante (el agente NO sustituye a un abogado)
- Legislación europea no transpuesta a España

---

## 3. Arquitectura del agente

### 3.1. Componentes

```
legalize-es (git submodule o clone local)
        ↓
legal-index (índice semántico local)
        ↓
legal-compliance agent (Opus 4.6)
        ↓
Informe de compliance
```

### 3.2. Agente: `legal-compliance`

```yaml
---
name: legal-compliance
description: >
  Auditoría de compliance legal contra legislación española consolidada (legalize-es).
  Usar PROACTIVELY cuando: se crean reglas de negocio, se revisan contratos,
  se diseñan features con implicaciones legales, se audita un proyecto completo,
  o se necesita verificar cumplimiento normativo.
tools: [Read, Glob, Grep, Bash, Write]
model: opus
permissionMode: acceptEdits
maxTurns: 30
color: indigo
token_budget: 13000
permission_level: L2
---
```

### 3.3. Índice legislativo local

Para evitar cargar 12.235 ficheros en contexto, el agente opera en 3 fases:

**Fase 1 — Clasificación del input** (~500 tokens)
- Leer el documento/regla a auditar
- Identificar dominios legales relevantes (datos, laboral, consumo, etc.)
- Determinar CCAA si aplica

**Fase 2 — Búsqueda legislativa focalizada** (~3.000 tokens)
- Buscar con `grep -rl` en el directorio legalize-es por términos clave
- Filtrar por `legal_status: vigente` en frontmatter
- Cargar solo los artículos relevantes (no la norma completa)
- Máximo 10 normas por auditoría (priorizar por rango regulatorio)

**Fase 3 — Análisis de compliance** (~8.000 tokens)
- Cruzar cada regla/cláusula del input contra artículos encontrados
- Clasificar hallazgos por severidad
- Generar informe estructurado

### 3.4. Priorización de normas por rango

```
1. Constitución Española
2. Leyes Orgánicas (LO)
3. Leyes ordinarias
4. Reales Decretos-ley (RDL)
5. Reales Decretos (RD)
6. Órdenes Ministeriales
7. Resoluciones
8. Normas autonómicas (según CCAA del proyecto)
```

---

## 4. Contrato técnico

### 4.1. Comando: `/legal-audit`

```
/legal-audit [--project {nombre}] [--scope {rules|contract|architecture|policy|pbi|full}]
             [--domain {datos|laboral|consumo|accesibilidad|ciber|all}]
             [--ccaa {es-ct|es-md|es-an|...}] [--format {summary|detailed|executive}]
```

**Parámetros:**
- `--project`: proyecto a auditar (default: proyecto activo)
- `--scope`: qué auditar (default: `rules`)
- `--domain`: dominio legal a priorizar (default: `all` — auto-detectar)
- `--ccaa`: comunidad autónoma para normativa regional (default: solo estatal)
- `--format`: nivel de detalle del informe (default: `detailed`)

### 4.2. Output

Fichero: `output/legal/{YYYYMMDD}-legal-audit-{proyecto}.md`

```markdown
# Auditoría Legal — {Proyecto}
> Fecha: YYYY-MM-DD | Scope: {scope} | Dominio: {dominio}
> Fuente legislativa: legalize-es (commit {hash}, {fecha})

## Resumen Ejecutivo
- Hallazgos: N total (X críticos, Y altos, Z medios, W informativos)
- Cobertura: X% de reglas con base legal identificada
- Dominios auditados: {lista}

## Hallazgos

### [CRÍTICO] {Título del hallazgo}
- **Regla/Cláusula**: {referencia al input}
- **Norma aplicable**: {nombre norma} — Art. {N}
- **ELI**: {enlace ELI}
- **Incumplimiento**: {descripción precisa}
- **Riesgo**: {sanción, nulidad, responsabilidad}
- **Recomendación**: {acción concreta}

### [ALTO] ...
### [MEDIO] ...
### [INFO] ...

## Matriz de Trazabilidad
| Regla/Cláusula | Norma | Artículo | Estado | Severidad |
|----------------|-------|----------|--------|-----------|
| RN-001 | LOPDGDD | Art. 13 | CUMPLE | — |
| RN-002 | LSSI | Art. 22.2 | NO CUMPLE | Crítico |

## Normas consultadas
- {Norma 1} ({ELI}) — {N} artículos relevantes
- {Norma 2} ({ELI}) — {N} artículos relevantes

## Disclaimer
Este informe es orientativo. No constituye asesoramiento jurídico.
Consulte con un profesional del derecho para decisiones vinculantes.
```

### 4.3. Clasificación de severidad

| Severidad | Criterio | Ejemplo |
|-----------|----------|---------|
| **Crítico** | Sanción >100K€, nulidad contractual, responsabilidad penal | Tratamiento datos sin base legal |
| **Alto** | Sanción 10-100K€, obligación incumplida con plazo | Falta de aviso legal en web |
| **Medio** | Recomendación regulatoria no cumplida, riesgo reputacional | EIPD no realizada |
| **Info** | Buena práctica no implementada, mejora preventiva | Registro de actividades incompleto |

---

## 5. Instalación de legalize-es

### 5.1. Como git submodule (recomendado)

```bash
# Añadir como submodule (no entra en el repo de pm-workspace)
git submodule add https://github.com/legalize-dev/legalize-es.git \
  data/legalize-es

# Actualizar legislación
cd data/legalize-es && git pull origin main
```

### 5.2. Como clone independiente

```bash
# Clone en directorio local (fuera del repo)
git clone --depth=1 https://github.com/legalize-dev/legalize-es.git \
  ~/.savia/legalize-es

# Configurar ruta
LEGALIZE_ES_PATH="$HOME/.savia/legalize-es"
```

### 5.3. Configuración en pm-config.local.md

```
LEGALIZE_ES_PATH            = "$HOME/.savia/legalize-es"
LEGALIZE_ES_AUTO_UPDATE     = true
LEGALIZE_ES_UPDATE_INTERVAL = "daily"
LEGALIZE_ES_DEFAULT_CCAA    = ""          # vacío = solo estatal
```

---

## 6. Skill: `legal-compliance`

```yaml
---
name: legal-compliance
description: >
  Auditoría de compliance legal contra legislación española consolidada.
  Cruza reglas de negocio, contratos y políticas contra legalize-es.
  Usar cuando se revisan aspectos legales de un proyecto.
category: governance
context: Carga bajo demanda. Requiere legalize-es clonado localmente.
user-invocable: true
allowed-tools: [Read, Bash, Glob, Grep, Write]
---
```

### DOMAIN.md

```markdown
## Por qué existe esta skill

Los proyectos de software tienen obligaciones legales que a menudo se
descubren tarde (en producción, ante una reclamación, o en una auditoría).
Esta skill permite detectar incumplimientos normativos en fase de diseño,
antes de que generen riesgo real.

## Conceptos de dominio

- **Norma consolidada**: Texto legal con todas las reformas integradas
- **ELI**: European Legislation Identifier — URL canónica de cada norma
- **Rango regulatorio**: Jerarquía normativa (Constitución > LO > Ley > RD)
- **CCAA**: Comunidad Autónoma — legislación regional complementaria
- **Base legal**: Fundamento jurídico que habilita una actividad

## Reglas de negocio que implementa

- Trazabilidad regla→artículo (compliance auditable)
- Priorización por rango normativo (jerarquía legal)
- Detección de conflictos norma estatal vs autonómica

## Relación con otras skills

- Upstream: `regulatory-compliance` (framework genérico de compliance)
- Upstream: `product-discovery` (descubre requisitos legales en discovery)
- Downstream: `spec-driven-development` (specs incluyen constraints legales)
- Paralelo: `security-pipeline` (ciberseguridad tiene base legal: ENS, NIS2)

## Decisiones de diseño

- **grep sobre embeddings**: El corpus es estable y estructurado. Grep
  en frontmatter + texto es más determinista que búsqueda vectorial para
  legislación. Sin dependencias externas (Principio #2: independencia).
- **No incluir jurisprudencia v1**: Las sentencias requieren un parser
  diferente y cambian la naturaleza del output (de cumplimiento a riesgo).
```

---

## 7. Estrategia de búsqueda legislativa

### 7.1. Índice de términos clave por dominio

Mantener un fichero `legal-compliance/references/domain-terms.md` con:

```markdown
## Protección de datos
normas: [BOE-A-2018-16673, BOE-A-2018-12131]
términos: [datos personales, consentimiento, responsable tratamiento,
           encargado, EIPD, delegado protección, derecho supresión,
           portabilidad, limitación, oposición, base legal]

## Comercio electrónico
normas: [BOE-A-2002-13758]
términos: [servicio sociedad información, aviso legal, cookies,
           comunicaciones comerciales, contratación electrónica]
```

### 7.2. Algoritmo de búsqueda

```
1. Extraer términos clave del input (regla/contrato/doc)
2. Mapear términos → dominios (domain-terms.md)
3. Para cada dominio:
   a. Buscar en normas conocidas del dominio (fast path)
   b. Si no hay match → grep amplio en legalize-es (slow path)
4. Filtrar resultados por legal_status: vigente
5. Ordenar por rango regulatorio (Constitución primero)
6. Cargar solo artículos relevantes (no norma completa)
7. Máximo 10 normas, ~50 artículos por auditoría
```

### 7.3. Historial de reformas

El agente puede usar `git log` sobre legalize-es para:
- Verificar que un artículo sigue vigente
- Mostrar la última reforma que lo modificó
- Alertar si una norma fue derogada recientemente

```bash
# ¿Cuándo se reformó por última vez el artículo?
git -C $LEGALIZE_ES_PATH log --oneline -5 -- es/BOE-A-2018-16673.md
```

---

## 8. Integración con pm-workspace

### 8.1. Hooks

| Evento | Acción | Condición |
|--------|--------|-----------|
| PostToolUse (Write) | Sugerir `/legal-audit` | Si se escribe `reglas-negocio.md` |
| Stop (pre-PR) | Incluir en PR checklist | Si proyecto tiene `legal_compliance: true` |

### 8.2. Integración con verticales

| Vertical | Normas adicionales auto-cargadas |
|----------|--------------------------------|
| Healthcare | Ley 41/2002, RD 1720/2007 |
| Finance | Ley mercado valores, PSD2, Verifactu |
| Education | LOMLOE, normativa becas |
| Legal | LEC, LECrim, Ley Enjuiciamiento |

### 8.3. Integración con agentes existentes

| Agente | Interacción |
|--------|-------------|
| `business-analyst` | Enriquece reglas de negocio con base legal |
| `architect` | Valida privacy-by-design contra RGPD |
| `security-guardian` | Cruza hallazgos de seguridad con ENS/NIS2 |
| `sdd-spec-writer` | Añade constraints legales a specs |

---

## 9. Constraints

| Dimensión | Requisito |
|-----------|-----------|
| **Rendimiento** | Auditoría completa <60s (fase 2: grep <10s) |
| **Contexto** | Máx 8.000 tokens de legislación por auditoría |
| **Privacidad** | Legislación es pública — no aplica N4. El input SÍ puede ser N4 |
| **Disponibilidad** | Funciona offline si legalize-es está clonado |
| **Actualización** | `git pull` diario (automático si configurado) |
| **Idioma** | Output en español. Legislación ya está en español |
| **Disclaimer** | SIEMPRE incluir disclaimer de no asesoramiento jurídico |

---

## 10. Test scenarios

### Happy path

```
Given: proyecto con reglas-negocio.md que menciona "datos personales"
When: /legal-audit --scope rules --domain datos
Then: informe con trazabilidad RN→Art LOPDGDD, 0 errores de búsqueda
```

### Norma derogada

```
Given: referencia a una norma derogada en el contrato
When: /legal-audit --scope contract
Then: hallazgo CRÍTICO indicando derogación + norma sustitutiva
```

### Sin legalize-es instalado

```
Given: LEGALIZE_ES_PATH no existe o directorio vacío
When: /legal-audit
Then: error con instrucciones de instalación (git clone)
```

### CCAA específica

```
Given: proyecto en Cataluña con normativa de consumo
When: /legal-audit --ccaa es-ct --domain consumo
Then: informe incluye Codi de Consum de Catalunya + normativa estatal
```

### Proyecto sin reglas de negocio

```
Given: proyecto sin reglas-negocio.md
When: /legal-audit --scope rules
Then: aviso "No se encontraron reglas de negocio" + sugerir crearlas
```

---

## 11. Implementación por fases

### Fase 1 — MVP (1 sprint)
- Clonar legalize-es como dependencia local
- Crear agente `legal-compliance` con búsqueda por grep
- Crear skill con `domain-terms.md` para los 4 dominios principales
- Comando `/legal-audit` con scope `rules` y `contract`
- Informe básico con trazabilidad

### Fase 2 — Ampliación (1 sprint)
- Añadir scopes: `architecture`, `policy`, `pbi`, `full`
- Integración con verticales (healthcare, finance, education)
- Historial de reformas (`git log`)
- Detección de normas derogadas

### Fase 3 — Inteligencia (futuro)
- Índice semántico local (embeddings con Ollama) para búsqueda difusa
- Sugerencia proactiva al escribir reglas de negocio
- Alertas cuando legalize-es actualiza una norma referenciada por el proyecto
- Dashboard de compliance legal por proyecto

---

## 12. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Interpretación legal incorrecta | Alto — falsa confianza | Disclaimer obligatorio + revisión humana |
| Norma no encontrada por grep | Medio — falso negativo | domain-terms.md curado + fallback a búsqueda amplia |
| legalize-es desactualizado | Medio — legislación obsoleta | Auto-update diario + mostrar fecha de último pull |
| Corpus demasiado grande para contexto | Bajo — degradación | Máx 10 normas, carga por artículos, no por norma |
| Conflicto norma estatal vs autonómica | Medio — ambigüedad | Priorizar por rango + flag al usuario |

---

## 13. Disclaimer legal (obligatorio en todo output)

```
⚖️ AVISO: Este análisis es orientativo y no constituye asesoramiento
jurídico profesional. Las conclusiones deben ser validadas por un
profesional del derecho antes de tomar decisiones vinculantes.
Fuente legislativa: legalize-es (legislación consolidada del BOE).
```

---

*SPEC-079 — Propuesta · 2026-04-07 · Dominio: governance · Vertical: transversal*
