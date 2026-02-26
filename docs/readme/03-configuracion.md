# Configuración Inicial

## Requisitos previos

- [Claude Code](https://docs.claude.ai/claude-code) instalado y autenticado (`claude --version`)
- [Azure CLI](https://docs.microsoft.com/es-es/cli/azure/install-azure-cli) con extensión `az devops`
- Node.js ≥ 18 (para scripts de reporting)
- Python ≥ 3.10 (para capacity calculator)
- `jq` instalado (`apt install jq` / `brew install jq`)

## Paso 1 — PAT de Azure DevOps

```bash
mkdir -p $HOME/.azure
echo -n "TU_PAT_AQUI" > $HOME/.azure/devops-pat
chmod 600 $HOME/.azure/devops-pat
```

El PAT necesita estos scopes: Work Items (Read & Write), Project and Team (Read), Analytics (Read), Code (Read).

```bash
# Verificar conectividad
az devops configure --defaults organization=https://dev.azure.com/MI-ORGANIZACION
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
az devops project list --output table
```

## Paso 2 — Editar las constantes

Abre `CLAUDE.md` y actualiza la sección `⚙️ CONSTANTES DE CONFIGURACIÓN`. Repite en `projects/proyecto-alpha/CLAUDE.md` y `projects/proyecto-beta/CLAUDE.md` para los valores específicos de cada proyecto.

## Paso 3 — Instalar dependencias de scripts

```bash
cd scripts/
npm install
cd ..
```

## Paso 4 — Clonar el código fuente

```bash
# Para que SDD funcione, el código del proyecto debe estar disponible localmente
cd projects/proyecto-alpha/source
git clone https://dev.azure.com/TU-ORG/ProyectoAlpha/_git/proyecto-alpha .
cd ../../..
```

## Paso 5 — Verificar la conexión

```bash
chmod +x scripts/azdevops-queries.sh
./scripts/azdevops-queries.sh sprint ProyectoAlpha "ProyectoAlpha Team"
```

## Paso 6 — Abrir con Claude Code

```bash
# Siempre desde la raíz del workspace (donde está el CLAUDE.md y la carpeta .claude/)
cd ~/claude    # o el directorio donde hayas clonado el repositorio
claude
```

Claude Code cargará `CLAUDE.md` automáticamente, activará los 35 comandos y las 9 skills,
detectará el lenguaje del proyecto y cargará las convenciones y agente apropiados.
Todas las buenas prácticas del flujo Explorar → Planificar → Implementar → Commit están preconfiguradas.

---

## Ejemplo — Cómo queda el CLAUDE.md de un proyecto configurado

_Escenario: Tienes un proyecto llamado "GestiónClínica" en Azure DevOps, con equipo "GestiónClínica Team". Así quedan las constantes en `projects/gestion-clinica/CLAUDE.md`:_

```yaml
PROJECT_NAME            = "GestiónClínica"
PROJECT_TEAM            = "GestiónClínica Team"
AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/miempresa"
CURRENT_SPRINT_PATH     = "GestiónClínica\\Sprint 2026-04"
VELOCITY_HISTORICA      = 38   # SP medios de los últimos 5 sprints
SPRINT_DURATION_DAYS    = 10
FOCUS_FACTOR            = 0.75

# Equipo (nombres exactos como aparecen en Azure DevOps)
TEAM_MEMBERS:
  - nombre: "Carlos Mendoza"    role: "Tech Lead"   horas_dia: 6
  - nombre: "Laura Sánchez"     role: "Full Stack"  horas_dia: 7.5
  - nombre: "Diego Torres"      role: "Backend"     horas_dia: 7.5
  - nombre: "Ana Morales"       role: "QA"          horas_dia: 7.5

sdd_config:
  token_budget_usd: 25
  agentization_target: 0.60
```

**A partir de aquí, Claude conoce tu organización, equipo y proyecto.**
No tienes que repetir este contexto en cada conversación.

---
