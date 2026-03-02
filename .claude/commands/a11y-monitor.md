---
name: /a11y-monitor
description: "Monitorización continua de regresiones de accesibilidad. Integración en CI/CD. Alertas cuando score baja por debajo de threshold. Digest semanal. Previene regresiones bloqueando deploys con fallos a11y."
developer_type: all
agent: task
context_cost: medium
---

# /a11y-monitor — Monitorización Continua de Accesibilidad

Integra auditorías de accesibilidad en tu pipeline CI/CD. Detecta regresiones automáticamente y bloquea deploys si el score cae por debajo del threshold.

## Sintaxis

```bash
/a11y-monitor [--enable] [--threshold score] [--ci] [--lang es|en]
```

## Parámetros

- `--enable` — Activar monitorización continua
- `--threshold` — Score mínimo aceptable (0-100, default 70)
- `--ci` — Configurar integración con CI/CD (GitHub Actions, Azure Pipelines)
- `--lang` — Idioma (`es` o `en`)

## Modos

**Local**: Ejecutar en máquina del desarrollador antes de push
```bash
/a11y-monitor --threshold 75
```

**CI/CD**: Ejecutar como step en pipeline
```bash
/a11y-monitor --ci --threshold 75
```

## Comportamiento

1. **Pre-deploy**: Ejecuta auditoría WCAG 2.2 AA
2. **Score Check**: Compara con score anterior
3. **Threshold**: Si score < threshold → BLOQUEA deployment
4. **Regresión**: Si score baja respecto a última ejecución → ALERTA
5. **Digest**: Envía resumen semanal por email/Slack

## Integración CI/CD

### GitHub Actions
```yaml
- name: Accessibility Monitor
  run: /a11y-monitor --ci --threshold 75
```

### Azure Pipelines
```yaml
- script: /a11y-monitor --ci --threshold 75
  displayName: Accessibility Monitor
```

## Alertas

- Score por debajo threshold → BLOQUEA deploy
- Regresión respecto baseline → ALERTA (no bloquea)
- Nuevos críticos → NOTIFICACIÓN
- Sin cambios críticos en 7 días → Digest positivo

## Ejemplos

```bash
/a11y-monitor --enable --threshold 75 --lang es
/a11y-monitor --ci --threshold 80
/a11y-monitor --enable --lang es
```

## Características

**Automático**: Ejecuta en cada commit/PR.

**Bloqueador**: Previene deploys con regresiones.

**Digest**: Resumen semanal de evolución.

**Histórico**: Tracking de score a lo largo del tiempo.

**CI Ready**: GitHub Actions, Azure Pipelines, GitLab CI.

## Beneficios

Evita que problemas de accesibilidad se introduzcan en producción. Responsabiliza al equipo manteniendo score consistente.
