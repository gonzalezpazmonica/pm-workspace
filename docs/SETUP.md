# Guía de Inicio Rápido — PM-Workspace

## Paso 1 — Configurar el PAT de Azure DevOps

```bash
# Crear el directorio y fichero del PAT
mkdir -p $HOME/.azure
echo -n "TU_PAT_AQUI" > $HOME/.azure/devops-pat
chmod 600 $HOME/.azure/devops-pat

# Verificar
az devops configure --defaults organization=https://dev.azure.com/MI-ORGANIZACION
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
az devops project list --output table
```

**Scopes del PAT requeridos:**
- Work Items: Read & Write
- Project and Team: Read
- Analytics: Read
- Code: Read

---

## Paso 2 — Editar las constantes

Abre `CLAUDE.md` y edita la sección `⚙️ CONSTANTES DE CONFIGURACIÓN`:

```
AZURE_DEVOPS_ORG_URL   → URL de tu organización
AZURE_DEVOPS_ORG_NAME  → Nombre de la organización
PROJECT_ALPHA_NAME     → Nombre exacto del proyecto en Azure DevOps
PROJECT_ALPHA_TEAM     → Nombre exacto del equipo
```

Repite para cada proyecto en `projects/proyecto-alpha/CLAUDE.md` y `projects/proyecto-beta/CLAUDE.md`.

---

## Paso 3 — Instalar dependencias de scripts

```bash
# GitHub CLI (necesario para crear PRs y gestionar repos desde Claude Code)
sudo apt update && sudo apt install gh -y   # Ubuntu/Debian
# o: brew install gh                         # macOS
gh auth login

# Node.js dependencies para report-generator
cd scripts/
npm install
cd ..
```

---

## Paso 4 — Clonar el código fuente de cada proyecto

```bash
# Proyecto Alpha
cd projects/proyecto-alpha/source
git clone https://dev.azure.com/MI-ORGANIZACION/ProyectoAlpha/_git/proyecto-alpha .
cd ../../..

# Proyecto Beta
cd projects/proyecto-beta/source
git clone https://dev.azure.com/MI-ORGANIZACION/ProyectoBeta/_git/proyecto-beta .
cd ../../..
```

---

## Paso 5 — Verificar la conexión

```bash
# Test de conectividad básica
chmod +x scripts/azdevops-queries.sh
./scripts/azdevops-queries.sh sprint ProyectoAlpha "ProyectoAlpha Team"
```

---

## Paso 6 — Configurar Claude Code para Agentes (opcional pero recomendado)

Para usar Spec-Driven Development con agentes Claude, necesitas la CLI de Claude Code disponible en el PATH:

```bash
# Verificar que claude CLI está instalado
claude --version

# Verificar que puedes invocar claude como subproceso (necesario para agent:run)
echo "Test de invocación de agente:"
claude --model claude-haiku-4-5-20251001 --max-turns 1 "Di 'Hola' en una sola palabra"

# Crear directorio de logs de agentes
mkdir -p output/agent-runs

# Verificar variables de entorno de API (si usas clave de API directa)
# Opción A: usar la misma sesión de claude autenticada
# Opción B: usar ANTHROPIC_API_KEY
echo ${ANTHROPIC_API_KEY:0:10}...   # Solo mostrar los primeros 10 chars
```

**Nota:** Si no configuras los agentes ahora, puedes usar el workspace sin SDD y activarlo en cualquier momento.

---

## Paso 7 — Abrir con Claude Code

```bash
# Desde la raíz de pm-workspace/
claude
```

Claude Code leerá automáticamente `CLAUDE.md` y estará listo para usar.

---

## Comandos Disponibles

Una vez dentro de Claude Code:

### Gestión de Sprint y Reporting

| Comando | Descripción |
|---------|-------------|
| `/sprint:status` | Estado del sprint actual |
| `/sprint:plan` | Asistente de sprint planning |
| `/sprint:review` | Generar resumen de sprint review |
| `/sprint:retro` | Plantilla de retrospectiva con datos |
| `/report:hours` | Informe de imputación de horas (Excel) |
| `/report:executive` | Informe ejecutivo multi-proyecto (PPT/Word) |
| `/report:capacity` | Estado de capacidades del equipo |
| `/team:workload` | Carga de trabajo por persona |
| `/board:flow` | Análisis del flujo y cuellos de botella |
| `/kpi:dashboard` | Dashboard completo de KPIs |

### Descomposición de PBIs

| Comando | Descripción |
|---------|-------------|
| `/pbi:decompose {id}` | Descomponer un PBI en tasks con estimación y asignación |
| `/pbi:decompose-batch {ids}` | Descomponer varios PBIs optimizando la carga global |
| `/pbi:assign {pbi_id}` | (Re)asignar tasks existentes de un PBI |
| `/pbi:plan-sprint` | Planning completo: capacity + PBIs + descomposición |

### Spec-Driven Development (SDD) — Agentes Claude

| Comando | Descripción |
|---------|-------------|
| `/spec:generate {task_id}` | Generar Spec ejecutable desde una Task de Azure DevOps |
| `/spec:implement {spec_file}` | Implementar Spec (lanza agente o asigna humano) |
| `/spec:review {spec_file}` | Revisar calidad de Spec o validar implementación |
| `/spec:status` | Dashboard de estado de todas las Specs del sprint |
| `/agent:run {spec_file}` | Lanzar agente Claude directamente sobre una Spec |

---

## Estructura de Ficheros Clave

```
CLAUDE.md                                    ← Léelo primero (contexto global + constantes)
.claude/skills/                              ← Skills que Claude Code puede invocar
  ├── pbi-decomposition/SKILL.md             ← Descomposición inteligente de PBIs
  └── spec-driven-development/SKILL.md       ← SDD: specs para humanos y agentes
      └── references/
          ├── spec-template.md               ← Plantilla de specs
          ├── layer-assignment-matrix.md     ← Qué capa → human vs agent
          └── agent-team-patterns.md         ← Patrones de equipos de agentes
docs/                                        ← Reglas de negocio, KPIs, plantillas
projects/<proyecto>/CLAUDE.md               ← Contexto específico + config SDD
projects/<proyecto>/equipo.md               ← Equipo humano + agentes Claude
projects/<proyecto>/source/                  ← Código fuente (git clone)
projects/<proyecto>/specs/                   ← Specs SDD del proyecto
  ├── sdd-metrics.md                         ← Métricas históricas de SDD
  ├── templates/                             ← Plantilla de spec
  └── sprint-YYYY-MM/                        ← Specs del sprint actual
scripts/azdevops-queries.sh                  ← Queries a Azure DevOps (bash)
scripts/report-generator.js                 ← Generador de informes (Node.js)
scripts/capacity-calculator.py              ← Cálculo de capacidades (Python)
output/                                      ← Informes generados (no commitear)
output/agent-runs/                           ← Logs de ejecuciones de agentes
```

---

## Problemas Frecuentes

| Problema | Solución |
|----------|----------|
| `TF400813: Not authorized` | Verificar PAT: `cat $HOME/.azure/devops-pat` + scopes |
| `az: command not found` | Instalar Azure CLI: https://aka.ms/installazurecliwindows |
| `jq: command not found` | `apt install jq` / `brew install jq` |
| `gh: command not found` | `sudo apt install gh` / `brew install gh` + `gh auth login` |
| Resultados vacíos del sprint | Verificar que el sprint está activo en Azure DevOps Team Settings |
| Node modules faltantes | `cd scripts && npm install` |

---

## Problemas Frecuentes

| Problema | Solución |
|----------|----------|
| `TF400813: Not authorized` | Verificar PAT: `cat $HOME/.azure/devops-pat` + scopes |
| `az: command not found` | Instalar Azure CLI: https://aka.ms/installazurecliwindows |
| `jq: command not found` | `apt install jq` / `brew install jq` |
| Resultados vacíos del sprint | Verificar que el sprint está activo en Azure DevOps Team Settings |
| Node modules faltantes | `cd scripts && npm install` |
| `claude: command not found` (para SDD) | Instalar claude CLI: https://docs.claude.ai/claude-code |
| Agente para inmediatamente sin error | Revisar la Spec — probablemente hay un campo "{placeholder}" sin rellenar |
| Build falla tras ejecución de agente | Verificar sección 5 de la Spec — puede haber fichero que falta |

---

## Roadmap de Implementación (según propuesta)

- **Semanas 1-2 (Fase 1):** ✅ Estructura creada — Configurar PAT y probar conectividad
- **Semanas 3-4 (Fase 2):** Iterar con `/sprint:status` y `/team:workload` — documentar ajustes
- **Semanas 5-6 (Fase 3):** Activar `/report:hours` y `/report:executive` con datos reales
- **Semanas 7-8 (Fase 4):** Activar SDD — generar primeras specs con `/spec:generate` y probar agente con una task piloto
- **Semana 9+ (Fase 5):** Escalar SDD — objetivo 60% de tasks técnicas repetitivas por agente
