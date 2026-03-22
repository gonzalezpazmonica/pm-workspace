# SPEC-014: Competence Model for User Profiles

> Status: **DRAFT** · Fecha: 2026-03-22
> Origen: Fabrik-Codek — four-signal competence scoring
> Impacto: Savia adapta explicaciones por dominio automaticamente

---

## Problema

Savia conoce el rol del usuario (PM, Tech Lead, Developer) pero no su
nivel de expertise por dominio. Un Tech Lead puede ser experto en .NET
pero novato en Terraform. Hoy adaptive-output.md usa el rol como proxy,
que es impreciso: trata igual a un senior .NET y a un junior .NET.

Fabrik-Codek resuelve esto con 4 senales independientes que clasifican
expertise como Expert/Competent/Novice/Unknown por tema.

---

## Diseno

### Fragmento competence.md en perfil de usuario

```yaml
# .claude/profiles/users/{slug}/competence.md
---
updated: 2026-03-22
---

## Competence by Domain

| Domain | Level | Signals | Last active |
|--------|-------|---------|-------------|
| dotnet | expert | entries:45 recency:3d outcomes:0.92 | 2026-03-21 |
| terraform | novice | entries:2 recency:30d outcomes:0.50 | 2026-02-20 |
| sprint-mgmt | expert | entries:120 recency:1d outcomes:0.88 | 2026-03-22 |
| python | competent | entries:15 recency:14d outcomes:0.75 | 2026-03-08 |
| security | unknown | entries:0 | — |
```

### Cuatro senales

| Senal | Fuente | Formula |
|-------|--------|---------|
| Entry count | Comandos ejecutados por dominio | log2(count + 1) normalizado 0-1 |
| Recency | Ultimo uso del dominio | exp_decay(days, half_life=30) |
| Outcome rate | Exitos vs fallos en ese dominio | successes / total |
| Depth | Complejidad de comandos usados | ponderado por context_cost del cmd |

### Clasificacion

| Level | Criterio |
|-------|----------|
| Expert | score >= 0.75 Y entries >= 20 |
| Competent | score >= 0.50 Y entries >= 5 |
| Novice | score >= 0.25 O entries >= 1 |
| Unknown | entries == 0 |

Score = weighted_avg(entry_norm, recency, outcome, depth) con pesos
adaptativos: si falta una senal, su peso se redistribuye entre las demas
(patron de Fabrik-Codek con 8 weight sets predefinidos).

### Integracion con adaptive-output.md

| Competence | Output style |
|------------|-------------|
| Expert | Denso, sin explicaciones, asume conocimiento |
| Competent | Normal, explicaciones breves cuando hay matiz |
| Novice | Paso a paso, links a docs, mas contexto |
| Unknown | Preguntar nivel antes de actuar |

### Dominios detectados automaticamente

Mapeo de comandos/skills a dominios:

| Dominio | Comandos/skills que lo alimentan |
|---------|--------------------------------|
| dotnet | spec-generate (dotnet), dev-session (dotnet), pr-review (.cs) |
| typescript | spec-generate (ts), dev-session (ts), pr-review (.ts) |
| sprint-mgmt | sprint-*, daily-*, velocity-*, board-* |
| security | security-*, a11y-*, compliance-*, aepd-* |
| architecture | arch-*, adr-*, diagram-* |
| devops | pipeline-*, deploy-*, infra-* |
| testing | test-*, spec-verify-*, coverage-* |

---

## Implementacion

### Fase 1 — Tracking pasivo (1 sprint)

1. Hook PostToolUse que registra dominio del comando ejecutado
2. Almacena en `.claude/profiles/users/{slug}/competence-log.jsonl`
3. Sin clasificacion aun — solo acumula datos

### Fase 2 — Scoring y clasificacion (1 sprint)

1. Script `scripts/competence-score.sh` que lee el log y calcula scores
2. Genera/actualiza `competence.md` en el perfil
3. Se ejecuta al inicio de sesion (session-init) si log tiene nuevos datos

### Fase 3 — Integracion con adaptive-output (1 sprint)

1. Actualizar `adaptive-output.md` para leer competence.md
2. Comandos adaptan detalle por dominio, no solo por rol
3. Metricas: satisfaction proxy (reformulaciones post-respuesta)

---

## Criterios de aceptacion

- [ ] Tracking registra dominio de cada comando sin impacto en latencia
- [ ] Scoring clasifica correctamente en >= 85% de los casos (test manual)
- [ ] adaptive-output usa competence cuando existe, fallback a rol si no
- [ ] Unknown dispara pregunta al usuario en vez de asumir
- [ ] Datos en perfil local (N3), nunca en repo publico

---

## Ficheros afectados

- `.claude/profiles/users/{slug}/competence.md` — nuevo fragmento
- `.claude/profiles/users/{slug}/competence-log.jsonl` — nuevo log
- `.claude/rules/domain/adaptive-output.md` — integrar competence
- `.claude/rules/domain/context-tracking.md` — registrar dominio
- `scripts/competence-score.sh` — nuevo

---

## Riesgos

| Riesgo | Mitigacion |
|--------|-----------|
| Clasificacion incorrecta frustra al usuario | Override manual: "soy experto en X" |
| Log crece sin limite | Rotacion a 1000 entries, archivo de antiguos |
| Sesgo: PM que no codea parece "novice" en todo tech | Dominios separados: sprint-mgmt vs dotnet |
| Privacidad: competence data es evaluativa | N3 estricto, nunca compartido |
