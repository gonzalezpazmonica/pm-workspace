# Spec: SE-302 — Savia Azure Cost Monitor

**Task ID:**        SE-302
**PBI padre:**      SE-302 — Monitorizacion de costes Azure para Savia
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-04
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     python-developer (o rust-developer si se prefiere Rust)
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 90 min |
| Human effort | 4 h |
| Review effort | 30 min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 2h |

---

## 1. Contexto y Objetivo

Savia opera en infraestructura Azure (Azure DevOps para backlog/sprints, potencialmente
Azure VMs/ACI para ejecucion de agentes, Azure Container Registry, etc.). Actualmente
**no existe visibilidad de costes Azure** dentro del workspace.

El patron de optimizacion de costes cloud "save a few cents" aplica deteccion granular
de recursos idle y subutilizados. Su filosofia encaja con la mentalidad lean de Savia:
cada euro ahorrado en infra es un euro para inference.

**Objetivo**: añadir un script de monitorizacion de costes Azure que:
1. Consulte Azure Cost Management API para obtener el spend del mes actual
2. Detecte recursos idle/underutilizados (VMs stopped-but-not-deallocated, IPs sin asignar, discos huerfanos)
3. Genere un dashboard markdown en `output/cost/azure-cost-{YYYYMM}.md`
4. Compare contra mes anterior (trend) y budget definido
5. Emita alertas si el spend proyectado excede el budget

**Diferenciador**: las herramientas existentes son binaries standalone. Savia integrara
la logica como skill invocable desde el workspace, con output markdown en lugar de
acciones automaticas de shutdown (siguiendo autonomous-safety: solo propone, no ejecuta).

---

## 2. Contrato Tecnico

### 2.1 Script de Extraccion de Costes

```python
# scripts/azure-cost-report.py
# Requiere: AZURE_SUBSCRIPTION_ID, credenciales via Azure CLI (az login) o service principal

import subprocess
import json
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class CostSummary:
    month: str
    total_spend_eur: float
    daily_average_eur: float
    projected_month_end_eur: float
    budget_eur: float
    budget_remaining_eur: float
    trend_vs_last_month_pct: float
    top_resources: List[Dict]  # [{name, spend, pct_of_total}]
    idle_resources: List[str]
    recommendations: List[str]

def fetch_cost_data(subscription_id: str, month: str = None) -> CostSummary:
    """
    Usa Azure Cost Management API via az CLI.
    No requiere SDK adicional — az CLI ya instalado en el workspace.

    1. az costmanagement query --subscription {id} --timeframe MonthToDate
    2. az resource list --query "[?properties.provisioningState=='Succeeded']"
    3. Cruzar spend vs actividad → detectar idle resources
    4. Comparar con mes anterior via az costmanagement query --timeframe LastMonth
    """
    pass

def detect_idle_resources(subscription_id: str) -> List[str]:
    """
    Detecta:
    - VMs stopped (estado stopped, pero recurso existe → se cobra disco)
    - Public IPs no asociadas a ningun recurso
    - Managed disks no attached
    - App Services sin trafico (>7d)
    - Azure DevOps agent pools sin uso (>30d)
    """
    pass
```

### 2.2 Formato de Output

```markdown
# Azure Cost Report — 2026-08

**Generated**: 2026-08-04 | **Subscription**: Savia-Dev | **Currency**: EUR

## Summary

| Metric | Value |
|---|---|
| Month-to-date spend | €247.32 |
| Daily average | €61.83 |
| Projected month-end | €1,916.73 |
| Monthly budget | €2,000.00 |
| Remaining | €1,752.68 |
| Trend vs July | +12.4% ▲ |

## Top 5 Resources by Spend

| Resource | Type | MTD Spend | % of Total |
|---|---|---|---|
| savia-agents-vm | VM (D4s_v3) | €89.40 | 36.1% |
| savia-devops-agents | DevOps Agent Pool | €52.10 | 21.1% |
| savia-container-registry | ACR Premium | €31.20 | 12.6% |
| savia-keyvault | Key Vault | €22.00 | 8.9% |
| savia-log-analytics | Log Analytics | €18.50 | 7.5% |

## Idle Resources Detected

| Resource | Type | Monthly Waste | Action |
|---|---|---|---|
| dev-agent-vm-03 | VM (stopped, not deallocated) | €22.40 | Deallocate or delete |
| unused-ip-2024 | Public IP (unassociated) | €3.60 | Delete |
| old-snapshot-202605 | Managed Disk (orphan) | €5.80 | Delete |

## Recommendations

1. **Deallocate dev-agent-vm-03**: ahorro estimado €22.40/mes. La VM lleva stopped 18 dias.
2. **Downgrade ACR de Premium a Standard**: ahorro estimado €18/mes. Premium solo justificado con >100GB storage.
3. **Consolidar agent pools DevOps**: 3 pools con <20% utilizacion cada uno. Unificar en 1 pool con auto-scale.
4. **Cleanup de IPs y discos**: 5 recursos huerfanos detectados. Ahorro estimado €12.80/mes.

## Budget Forecast

[barra de progreso: ||||||||||||||||------] 77% del mes, 12.4% del budget consumido
Si el spend continua al ritmo actual, el mes cerrara en €1,916.73 (dentro de budget).

**Risk level**: 🟢 LOW — proyeccion dentro del 95% del budget.
```

### 2.3 Integracion como Skill

```markdown
# Skill: azure-cost-monitor
# Fichero: .claude/skills/azure-cost-monitor/SKILL.md

Triggers: 'costes azure', 'azure spend', 'cloud costs', 'infra spend',
          'presupuesto cloud', 'ahorrar en azure', '/cost-report'

Pipeline:
1. AUTH: verificar que az CLI esta autenticado (az account show)
2. FETCH: ejecutar azure-cost-report.py --subscription $AZURE_SUBSCRIPTION_ID
3. ANALYZE: detectar idle resources, tendencias, anomalias
4. REPORT: generar output/cost/azure-cost-{YYYYMM}.md
5. ALERT: si projected > budget, emitir alerta en el daily brief
```

---

## 3. Inputs/Outputs

### Inputs
- `AZURE_SUBSCRIPTION_ID` (env var o `.claude/rules/pm-config.local.md`)
- Azure CLI autenticado (`az login` o service principal)
- `SAVIA_AZURE_BUDGET_MONTHLY_EUR` (opcional, default 2000€)

### Outputs
- `output/cost/azure-cost-{YYYYMM}.md` — informe mensual
- `output/cost/azure-cost-history.jsonl` — serie temporal para tendencias
- `output/cost/idle-resources-{date}.json` — recursos infrautilizados

---

## 4. Constraints and Limits

- NUNCA ejecutar az resource delete — solo recomendar
- NUNCA modificar recursos Azure — read-only
- Si az CLI no esta autenticado, mostrar instrucciones (no fallar silenciosamente)
- Timeout de consulta: 30s (las APIs de Cost Management son lentas)
- Cache de 24h para no saturar la API (az costmanagement query tiene rate limit)
- El script debe funcionar con zero deps mas alla de Python stdlib + az CLI

---

## 5. Test Scenarios

1. **Smoke test**: az costmanagement query devuelve datos → se genera informe markdown
2. **No auth**: az CLI no autenticado → mensaje de error claro con instrucciones
3. **Budget exceeded**: spend proyectado > budget → alerta en output
4. **Zero spend**: suscripcion sin gastos → informe con valores 0 (no crash)
5. **Idle detection**: VM stopped >7 dias → aparece en idle resources
6. **Historical trend**: comparar con mes anterior (usando datos cacheados)
7. **Subscription not found**: ID de suscripcion invalido → error claro

---

## 6. Ficheros a Crear/Modificar

### Crear
| Fichero | Proposito |
|---|---|
| `scripts/azure-cost-report.py` | Script principal de extraccion y analisis |
| `tests/test_azure_cost_report.py` | Tests unitarios |
| `.claude/skills/azure-cost-monitor/SKILL.md` | Definicion del skill |
| `output/cost/.gitkeep` | Directorio de output |

### Modificar
| Fichero | Cambio |
|---|---|
| `SKILLS.md` | Añadir entrada azure-cost-monitor |
| `CLAUDE.md` | Añadir referencia en lazy-loading |

---

## 7. Codigo de Referencia

- **Cloud cost optimization pattern**: deteccion de waste granular en Azure via Cost Management API
  - Topicos: azure, cloud, cost-optimization, infrastructure
  - Filosofia: "save a few cents" → deteccion de recursos idle y subutilizados
  - Enfoque: analisis via CLI, recomendaciones sin acciones automaticas
- **Azure Cost Management API**:
  - `az costmanagement query --type Usage --timeframe MonthToDate`
  - `az resource list` para inventario de recursos
- **Savia existente**:
  - `scripts/memory-store.sh` — patron de script CLI integrado
  - `docs/rules/domain/autonomous-safety.md` — principio "proponer, no ejecutar"

---

## 8. Estado de Implementacion

- [ ] S1: Script azure-cost-report.py (fetch + analyze)
- [ ] S2: Deteccion de idle resources
- [ ] S3: Generacion de informe markdown
- [ ] S4: Cache y rate limiting
- [ ] S5: Skill SKILL.md + integracion en catalogo
- [ ] S6: Tests
- [ ] S7: Documentacion
