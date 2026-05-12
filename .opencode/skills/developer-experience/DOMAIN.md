# Developer Experience — Dominio

## Por que existe esta skill

La productividad del equipo depende de la experiencia del desarrollador. Sin medirla,
las mejoras son intuiciones. Esta skill aplica los frameworks DX Core 4 y SPACE para
cuantificar velocidad, efectividad, calidad, impacto y carga cognitiva del equipo.

## Conceptos de dominio

- **DX Core 4**: cuatro pilares (Speed, Effectiveness, Quality, Impact) para medir experiencia del desarrollador
- **SPACE**: cinco dimensiones complementarias (Satisfaction, Performance, Activity, Communication, Efficiency)
- **Carga cognitiva**: tres tipos (intrinseca, extranea, germinal); reducir la extranea maximiza productividad
- **Feedback loop**: velocidad del ciclo PR-review, CI/CD, deteccion de errores; mas rapido = mejor DX
- **Metrica accionable**: metrica vinculada a umbral, trigger y accion concreta; medir sin actuar es ruido

## Reglas de negocio que implementa

- Adaptive Output (adaptive-output.md): modo coaching para juniors, tecnico para seniors
- Severity Classification (severity-classification.md): umbrales para clasificar metricas DX
- Self-Improvement Loop (Rule #21): descubrimientos de DX alimentan lecciones del workspace

## Relacion con otras skills

- **Upstream**: sprint-management (datos de velocity y completion), agent-trace (datos de latencia y fallos)
- **Downstream**: executive-reporting (consume scorecard DX para informes), spec-driven-development (DX informa prioridades de mejora)
- **Paralelo**: performance-audit (mide rendimiento del codigo; DX mide rendimiento del equipo)

## Decisiones clave

- Encuestas trimestrales con anonimato obligatorio: respuestas honestas requieren seguridad psicologica
- Minimo 3 dimensiones SPACE por medicion: una sola metrica nunca captura la realidad completa
- Integracion con agent-trace como proxy cuantitativo: evita depender solo de encuestas subjetivas
