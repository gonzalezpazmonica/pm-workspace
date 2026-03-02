---
name: playbook-evolve
description: Evolucionar playbook con insights — ciclo Generator→Reflector→Curator (ACE)
developer_type: all
agent: task
context_cost: high
---

# /playbook-evolve

> 🦉 El playbook aprende y mejora con cada generación.

Ciclo ACE: Generator (crear cambios) → Reflector (analizar impacto) →
Curator (aprobar evolución). Los playbooks se vuelven más eficientes generación a generación.

---

## Comando

```
/playbook-evolve {nombre} [--auto] [--conservative|aggressive] [--lang es|en]
```

**Parámetros:**
- `{nombre}` — Nombre del playbook a evolucionar
- `--auto` — Aplicar cambios automáticamente (sin confirmación)
- `--conservative` — Solo cambios de bajo riesgo (por defecto)
- `--aggressive` — Cambios más radicales (requiere confirmación)

---

## Proceso de Evolución

### Fase 1 — Recopilar reflexiones
Lee todas las reflexiones (`playbooks/reflections/{nombre}-*.md`)

### Fase 2 — Generator: Proponer cambios
Basado en reflexiones, generar candidatos con riesgo, impacto, rollback

### Fase 3 — Validar riesgo
- **Low** → apply automático si `--conservative`
- **Medium** → require `--aggressive` explícito
- **High** → require `--aggressive` + `--ab-test` + humano aprueba

### Fase 4 — A/B testing (opcional)
Ejecutar playbook 5 veces con cambios, comparar métricas, decidir evolucionar

### Fase 5 — Curator: Aplicar evolución
Guardar nueva generación en `playbooks/{nombre}.yml` con metrics (before/after)

---

## Output

```
🚀 Evolución automática: release (g2 → g3)

Cambios aplicados:
  ✅ Aumentar timeout (120s → 240s)
  ✅ Añadir retry logic

📊 Métricas esperadas:
  Success rate: 80% → 100%
  Failures por timeout: 1/5 → 0/5

🔄 Nueva generación: g3
   Playbook actualizado con 2 cambios de bajo riesgo.
```

---

## Generación y versionado

Cada evolución crea nueva generación (g1→g2→g3...):

```yaml
generation: g3
changes:
  - id: "ch1"
    change: "timeout: 120s → 240s"
    risk: "low"
    impact: "reduce_failures_from_1/5"
  
  - id: "ch2"
    change: "secuencial → paralelo (batch=10)"
    risk: "medium"
    impact: "reduce_duration_28m_to_2m"

metrics:
  before: {success_rate: "80%", avg_duration: "45min"}
  after: {success_rate: "100%", avg_duration: "8min"}
```

Cambios fallidos se revierten automáticamente.
