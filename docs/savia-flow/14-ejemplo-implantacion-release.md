# Ejemplo de Implantación: SocialApp — Fase 3: Release y Mejora

> Del primer deploy a producción al ciclo de mejora continua. Métricas, retro y lecciones.
> Continuación de [13-ejemplo-implantacion-dia-a-dia.md](13-ejemplo-implantacion-dia-a-dia.md).

---

## Semana 4 — Primer release a producción

### Pre-release: la usuaria verifica readiness

```
la usuaria → /release-readiness --project SocialApp
```

Savia audita: 3 specs deployed, gates pasados (lint, tests, security, QA review), bug #1010 resuelto, health checks OK. Resultado: ✅ Release readiness PASS. 3 features en DEV, 0 bugs abiertos. ⚠️ Recomendado: tests de carga antes de PRO.

### Deploy pipeline: DEV → PRE → PRO

Isabel verifica con `/pipeline-status`: Build ✅ → Tests ✅ → DEV ✅ (auto) → PRE ⏳. la usuaria aprueba PRE. Elena ejecuta tests de aceptación, aprueba. la usuaria aprueba PRO (doble gate: PM + PO).

### Post-deploy: validación de outcomes

Una vez en PRO, Elena valida que los outcomes se cumplen:

```
Elena → /outcome-track --epic "User Onboarding"
```

Savia muestra métricas reales vs target:

```
📊 Outcome: User Onboarding
  Signup completion: 68% (target 70%) — ⚠️ casi, monitorizar 1 semana
  Time to first post: 2.5 min (target <3 min) — ✅
  Bounce rate registro: 32% (target <30%) — ⚠️ close, revisar UX
```

Elena decide: el outcome necesita una iteración más. Crea nueva spec en exploración: "Onboarding UX Optimization" → simplificar formulario, A/B test.

---

## Mes 1 — Retro mensual (90 min)

### la usuaria facilita con datos

```
la usuaria → /flow-metrics --trend 4
la usuaria → /retro-patterns --sprints 4
```

Savia genera el dashboard del primer mes:

```
📊 Métricas mes 1:
  Cycle Time: 4.5d → 3.8d (mejorando ✅)
  Lead Time: 12d → 9d (mejorando ✅)
  Throughput: 2 → 3 items/semana (creciendo ✅)
  CFR: 0% (2 deploys sin incidentes ✅)
  Spec-Ready buffer: 1 → 3 (estabilizado ✅)
  Rework rate: 20% → 12% (specs reducen retrabajo ✅)
```

Savia también identifica patrones:

```
🔍 Patrones detectados:
  ✅ API contract first funciona — 0 bloqueos front↔back en semana 3-4
  ⚠️ Elena saturada en gates — considerar automatizar Gate 5 parcialmente
  ⚠️ Ana necesita más specs front-only — exploración muy back-heavy
  💡 Isabel podría hacer pair con Ana en componentes complejos Ionic
```

### El equipo decide

Acciones: (1) Elena automatiza parte de Gate 5 con checklist — solo items complejos requieren review manual. (2) Elena incluye más specs front-only en exploración. (3) Isabel dedica 2h/semana a pair programming con Ana en patrones Ionic avanzados.

---

## Mes 2-3 — El flujo maduro

### Cómo se ve el board en el mes 2

```
la usuaria → /flow-board
```

```
EXPLORACIÓN                              │ PRODUCCIÓN
Discovery    Spec-Writing   Spec-Ready   │ Ready    Building    Gates     Deployed
─────────────────────────────────────────────────────────────────────────────────
Push(#1012)  Groups(#1011)  DMs(#1007)   │ React.   Mentions   Notif.    Timeline
             Notif.C(#1009) Reac.(#1006) │ (#1008)  (#1005)    (#1004)   Feed, Reg
                                         │                               Profile
```

Buffer Spec-Ready: 2 items (saludable). Pipeline fluido. Elena ha encontrado su ritmo: 2-3 specs/semana.

### El ritmo del equipo estabilizado

Cada persona ha interiorizado su flujo con Savia:

**la usuaria** (15 min/día): `/flow-board` por la mañana, `/flow-metrics` los lunes. Interviene solo cuando hay bottleneck o decisión de prioridad. El resto del tiempo hace trabajo de CEO/CTO.

**Elena** (discovery 60%, gates 40%): abre sesión con `/flow-spec` para escribir specs. Cuando hay items en Gates, cambia a QA. Si el buffer Spec-Ready baja de 3, prioriza exploración.

**Ana** (100% building): abre sesión con `/my-focus` para ver su siguiente item. Usa `/spec-generate --type human` para specs de componentes Ionic. Cuando termina, mueve a Gates.

**Isabel** (90% building, 10% arch): igual que Ana pero con microservicios. Consulta arquitectura cuando Elena le pide revisar restricciones técnicas de specs. Entrega API contracts primero para no bloquear a Ana.

---

## Release final: MVP en producción

### Semana 12 — Cierre del MVP

```
la usuaria → /flow-metrics --trend 12
```

Métricas finales del proyecto:

```
📊 SocialApp MVP — 12 semanas
  Features deployed: 12 (4 outcomes completos)
  Cycle Time: 3.2 días (media)
  Lead Time: 8 días (media)
  Throughput: 3.5 items/semana (estable)
  CFR: 2% (1 incidente menor en 50 deploys)
  Rework rate: 8% (vs 60%+ sin specs)
  Specs escritas: 14 | Rechazadas: 1 | Iteradas: 3
```

```
la usuaria → /ceo-report --project SocialApp
```

Savia genera informe ejecutivo: MVP entregado en plazo, 4 outcomes validados, equipo de 4 personas. Stack completo funcionando: Ionic + 5 microservicios + RabbitMQ + MongoDB.

### Lecciones aprendidas

**Lo que funcionó**: specs ejecutables eliminaron 80% de ambigüedad (agentes correctos a la primera 85%), API contract first eliminó bloqueos front↔back desde semana 3, buffer Spec-Ready como indicador de salud del flujo, gates automáticos capturaron 12 bugs antes de QA humano.

**Lo que ajustamos**: Isabel subió WIP de 2 a 3 en mes 2 (microservicios pequeños), Gate 5 parcialmente automático (Elena no podía revisar todo), pair programming Isabel↔Ana 2h/semana (clave para crecimiento de Ana).

> **Índice completo**: [00-indice.md](00-indice.md)
