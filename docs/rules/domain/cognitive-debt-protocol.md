---
context_tier: L3
token_budget: 1200
spec_ref: SPEC-107
related_rules:
  - docs/rules/domain/emotional-regulation.md
  - docs/rules/domain/verification-before-done.md
---

# Cognitive Debt Protocol — SPEC-107

> Evidencia, señales y controles para mitigar la deuda cognitiva de sesiones
> intensas con IA. Complementa `wellbeing-guardian` (dimensión cognitiva,
> no emocional) y `burnout-radar` (indicador de baja ponderación).

## Evidencia base

### MIT Media Lab — "Your Brain on ChatGPT" (Kosmyna et al., 2025)

arXiv 2506.08872 · 54 participantes · EEG de 32 canales · 4 sesiones de redacción.

- Grupo LLM mostró **conectividad neural más débil** en bandas alpha/beta/theta/delta
  respecto al grupo sin IA. Patrón dosis-respuesta.
- **83% de los usuarios LLM no pudieron citar una sola frase** del ensayo que
  acababan de escribir minutos antes (vs ~11% sin LLM).
- Ensayos LLM estadísticamente homogéneos — pérdida de variación creativa.
- **Crossover crítico**: usuarios LLM→lápiz en sesión 4 mantuvieron subactivación.
  La deuda **persiste tras retirar la herramienta**.

### Microsoft Research + CMU — Lee et al., CHI 2025

319 trabajadores del conocimiento · 936 ejemplos de primera mano.

- **Mayor confianza en GenAI ↔ menos pensamiento crítico** (correlación negativa
  significativa).
- El esfuerzo cognitivo se desplaza a verificación/integración, pero los usuarios
  **saltan la verificación bajo presión de tiempo**.
- Tres barreras: (1) desconocer la necesidad de verificar, (2) presión temporal,
  (3) dificultad de refinar prompts en dominios no familiares.

### Carnegie Mellon / ICER 2025 — Copilot longitudinal

arXiv 2509.20353 · estudiantes de programación.

- Metacognición fuerte previa → beneficio con Copilot.
- Metacognición débil → rendimiento **peor con Copilot que sin él**.
- La atrofia es diferencial: los menos preparados pagan el coste mayor.

### Roediger & Karpicke 2006 — Retrieval Practice

Active recall produce **+50% retención a 1 semana** vs re-lectura.
Aplicación directa: **recordar antes de buscar** preserva memoria.

---

## Señales de alerta

| Señal | Umbral | Referencia |
|---|---|---|
| Sesión activa prolongada | > 4 horas continuas | MIT crossover threshold |
| Skip de verificación | verification\_rate < 50% | MS/CMU CHI 2025 barrera #2 |
| Velocidad anómala | > 15 tareas/h + baja verificación | MIT homogeneidad + MS/CMU |
| Trabajo nocturno | hora del día > 20:00 | Fatiga amplificadora |
| Aceptación rápida | > 40% aceptaciones en < 5s | MS/CMU proxy de skip |

---

## Controles recomendados

### Pausas estructuradas

- Al superar 4h de sesión activa: pausa de **15 min sin IA**.
- Al final del día: 20 min de revisión sin abrir herramientas.
- El hook `cognitive-debt-check.sh` emite el banner cuando se alcanza el límite.

### Double-checking explícito

- Antes de aceptar un output de IA: articula en voz alta por qué es correcto.
- Si no puedes explicarlo, no lo aceptes.
- Implementado como teach-back gate en SPEC-107 I2 (Phase 2).

### Hypothesis-first antes de pedir código

- Escribe tu hipótesis de solución **antes** de invocar a Claude (≥30 chars).
- Fundamento: Roediger-Karpicke — el retrieval previo consolida memoria.
- Implementado como commit trailer `Hypothesis:` en SPEC-107 I1 (Phase 2).

### Revisión humana obligatoria para score CRÍTICO

- Si `cognitive-load-score ≥ 76` → no merges sin revisión humana.
- El `cognitive-debt-monitor.py --json` produce el score para scripts.

### Weekly retrieval drill

- Lunes: `/retrieval-drill` selecciona 3 PRs recientes.
- Sin abrir código, describe en 2 frases qué hace y por qué esa decisión.
- Fundamento: Karpicke (2006) — retrieval espaciado +50% retención.

---

## Anti-patterns

| Anti-pattern | Por qué es peligroso |
|---|---|
| "Solo uno más" | Efecto acumulativo — el 4to sprint nocturno es el que persiste |
| Ignorar warnings del hook | El banner no bloquea; ignóralo y asumes la deuda |
| Medir solo commits/PRs | Pueden subir mientras la cognición baja (MIT/CMU) |
| Pomodoro sin desconexión real | Sin RCT que muestre efecto sobre cognitive debt específicamente |
| Flashcards generadas por IA | No hay contrato de retrieval espaciado — dependencia circular |

---

## Integración con otros componentes

| Componente | Cómo interactúa |
|---|---|
| `wellbeing-guardian` | Recibe `cognitive_load_score` como señal adicional |
| `burnout-radar` | Consume score cognitivo (peso bajo, complementario) |
| `cognitive-debt-monitor.py` | Calcula score desde CLI o scripts |
| `cognitive-debt-check.sh` | Hook PostTurn — emite banner en sesiones largas |
| `cognitive-debt-telemetry.sh` | Registra tool calls para telemetría I4 |
| `verification-before-done.md` | I3 operativiza Rule #22 con checklist en /pr-plan |

---

## Privacidad (CD-03 inviolable)

- Datos cognitivos: `~/.savia/cognitive-load/{user}.jsonl` — N3, gitignored.
- NUNCA expuestos a equipo, manager, ni reportes corporativos.
- Opt-out: `bash scripts/cognitive-debt.sh disable`.
- Borrado completo: `bash scripts/cognitive-debt.sh forget --confirm`.
- No telemetría externa. No envío a servidores.

---

## Referencias

- Kosmyna et al. 2025 — arxiv.org/abs/2506.08872
- Lee et al. CHI 2025 — microsoft.com/en-us/research/wp-content/uploads/2025/01/lee_2025_ai_critical_thinking_survey.pdf
- ICER 2025 — arxiv.org/pdf/2509.20353
- Roediger & Karpicke 2006 — retrieval practice
