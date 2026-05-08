---
name: context-profile
description: Perfilar consumo de contexto — qué consume más, generación de flame-graph, comparación entre sesiones
developer_type: all
agent: task
context_cost: high
---

# Comando: context-profile

## Sinopsis

Perfilar qué componentes consumen más contexto en la sesión actual. Generar reporte estilo flame-graph mostrando jerarquía de consumo. Comparar consumo entre sesiones. Identificar patrones de bloat.

## Sintaxis

```bash
/context-profile [--analyze] [--compare] [--lang es|en]
```

Flags:
- `--analyze` — análisis profundo del consumo actual (genera flame-graph style report)
- `--compare` — comparar consumo de la sesión actual vs. sesión anterior
- `--lang es|en` — idioma del output

## Comportamiento

### 1. Cargar perfil (si está activo)

Leer `.claude/profiles/active-user.md` → `active_slug`.
Cargar identity.md para contexto del usuario.

### 2. Análisis profundo (con `--analyze`)

Generar flame-graph style report mostrando jerarquía de consumo de mayor a menor:

```
📊 Context Consumption Profile

┌─ TOTAL: 52,400 tokens (32.8% de 160k)
│
├─ 🔴 conversation (45,000 | 85.9%)
│  ├─ last_10_messages (12,000 | 26.7%)
│  ├─ previous_messages (33,000 | 73.3%)
│  │  ├─ message_N-5 (5,000)
│  │  ├─ message_N-10 (8,000)
│  │  └─ ...
│  │
├─ 🟡 rules (2,500 | 4.8%)
│  ├─ role-workflows.md (1,200 | 48%)
│  ├─ context-health.md (800 | 32%)
│  └─ pm-workflow.md (500 | 20%)
│
├─ 🟠 commands (1,200 | 2.3%)
│  ├─ sprint-status.md (300)
│  ├─ report-hours.md (280)
│  └─ ... (8 comandos más, total 1,200)
│
├─ 🟢 tools (900 | 1.7%)
│  ├─ azure-devops MCP (450)
│  └─ slack MCP (450)
│
└─ 🔵 system (800 | 1.5%)
   └─ Claude instructions
```

### 3. Comparación de sesiones (con `--compare`)

Lectura de `$HOME/.pm-workspace/context-usage.log` (si existe).

Mostrar tabla:

| Métrica | Sesión Anterior | Sesión Actual | Cambio | Tendencia |
|---|---|---|---|---|
| Total tokens | 48,000 | 52,400 | +4,400 | ⬆️ +9% |
| Conversation | 41,000 | 45,000 | +4,000 | ⬆️ +9.7% |
| Rules | 2,200 | 2,500 | +300 | ⬆️ +13.6% |
| Commands | 1,200 | 1,200 | 0 | ➡️ sin cambio |
| Tools | 800 | 900 | +100 | ⬆️ +12.5% |
| Efficiency ratio | 1.2 tokens/msg | 1.08 tokens/msg | -0.12 | ⬇️ MEJOR |

**Patrón detectado**: Conversation crece lineal. Reglas crecen (más reglas activas).

### 4. Recomendaciones integradas

```
💡 Observaciones:
  ✅ Eficiencia mejorando (menos tokens/mensaje)
  ⚠️  Conversation excede 85% — considera /compact
  ⚠️  Rules creciendo (+13%) — verificar qué reglas se activan automáticamente
  📈 Tendencia: Sesiones últimas 3 días muestran patrón estable (48-52k tokens)
```

## Output

### Si `--analyze`

Flame-graph style report con jerarquía visual + tabla de top 10 consumidores.

### Si `--compare`

Tabla de sesiones + tendencia + recomendaciones.

## Notas

- **Frecuencia**: ejecutar si sospechas que contexto está sobrecargado
- **Historial**: mantén el log de context-usage para poder comparar
- **Patrón esperado**: conversation crece logarítmicamente (no exponencialmente)
- **Alert umbral**: si conversation > 90% del total → sugerir /compact urgente

## Integración

Conecta con:
- `/context-budget` — presupuesto token por capa
- `/context-defer` — lazy loading para reducir overhead
- `/context-compress` — compresión semántica
- `$HOME/.pm-workspace/context-usage.log` — historial de consumo

