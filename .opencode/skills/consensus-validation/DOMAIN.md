# Consensus Validation — Dominio

## Por que existe esta skill

Las decisiones criticas (specs ambiguas, PRs rechazados, cambios de seguridad) no deben
depender de un solo evaluador. Esta skill orquesta un panel de 4 jueces independientes
que evaluan en paralelo y producen un veredicto ponderado con regla de veto.

## Conceptos de dominio

- **Panel de 4 jueces**: reflection-validator, code-reviewer, business-analyst, performance-auditor
- **Score ponderado**: combinacion 0.3+0.3+0.2+0.2 de los scores normalizados de cada juez
- **Veto rule**: un hallazgo de seguridad o GDPR anula el score y produce REJECTED automatico
- **Dissent**: cuando un juez difiere >0.5 del promedio; escala APPROVED a CONDITIONAL
- **Verdicts finales**: APPROVED (>=0.75), CONDITIONAL (0.50-0.74), REJECTED (<0.50)

## Reglas de negocio que implementa

- Consensus Protocol (consensus-protocol.md): definicion completa del flujo de 4 jueces
- Adversarial Security (adversarial-security.md): hallazgos de seguridad activan veto
- Autonomous Safety (autonomous-safety.md): Code Review E1 siempre humano tras consensus

## Relacion con otras skills

- **Upstream**: spec-driven-development (genera specs que pueden requerir consensus), pr-review (PR rechazado activa consensus)
- **Downstream**: dev-session (consume veredicto para decidir si proceder con implementacion)
- **Paralelo**: performance-audit (el 4o juez usa esta skill internamente para detectar hotspots)

## Decisiones clave

- 4 jueces en paralelo via dag-scheduling: minimiza latencia total (120s max vs 480s secuencial)
- Veto ignora el score numerico: la seguridad no se negocia con promedios
- Timeout de 40s por juez con degradacion graceful: respuesta parcial mejor que bloqueo total
