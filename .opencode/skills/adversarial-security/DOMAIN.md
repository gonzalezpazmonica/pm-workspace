# Adversarial Security — Dominio

## Por que existe esta skill

Los equipos de desarrollo necesitan validar la seguridad de su codigo antes de cada release, pero un solo auditor tiene puntos ciegos. Esta skill implementa un modelo adversarial con tres agentes independientes (Red Team, Blue Team, Auditor) que se verifican mutuamente, eliminando sesgos y garantizando cobertura OWASP/STRIDE completa.

## Conceptos de dominio

- **Red Team (security-attacker)**: agente que busca vulnerabilidades mediante analisis estatico y dinamico sin conocer las defensas
- **Blue Team (security-defender)**: agente que propone correcciones a vulnerabilidades sin ver el informe del atacante
- **Auditor (security-auditor)**: juez independiente que evalua ambos informes y genera score final 0-100
- **CVSS simplificado**: puntuacion de vulnerabilidades con 4 factores ponderados para proyectos internos
- **STRIDE**: modelo de amenazas de Microsoft con 6 categorias (Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation)

## Reglas de negocio que implementa

- Score = 100 - (critical x 25 + high x 10 + medium x 3 + low x 1), floor 0
- Hallazgos critical/high bloquean merge a main si compliance-gate esta activo
- Ningun agente ve el trabajo del otro antes de completar (excepto auditor al final)
- Cada fix verificado recupera los puntos de su vulnerabilidad

## Relacion con otras skills

- **Upstream**: spec-driven-development (specs con requisitos de seguridad), architecture-intelligence (patrones detectados)
- **Downstream**: verification-lattice (Layer 3 security gate), code-improvement-loop (fixes automaticos)
- **Paralelo**: pentesting (testing dinamico complementario), regulatory-compliance (marco regulatorio)

## Decisiones clave

- Tres agentes independientes en vez de uno solo para eliminar sesgos de confirmacion
- CVSS simplificado (4 factores) en vez del completo porque proyectos internos no requieren granularidad NIST
- Score numerico 0-100 para facilitar comparacion entre sprints y proyectos
