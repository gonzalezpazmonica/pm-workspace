# Onboarding Dev — Dominio

## Por qué existe esta skill

El onboarding técnico de nuevos desarrolladores consume 4-8 semanas y depende excesivamente del buddy humano para preguntas repetitivas. Esta skill auto-genera documentación del proyecto, crea un plan personalizado 30/60/90, y configura un buddy IA de 3 capas que reduce el ramp-up a 5-10 días.

## Conceptos de dominio

- **Buddy IA de 3 capas (Manfred)**: Capa 1 (orientación: quién/dónde), Capa 2 (ejecución: setup/PR/deploy), Capa 3 (contexto: decisiones técnicas pasadas)
- **Plan 30/60/90**: Objetivos medibles por periodo adaptados al seniority del nuevo miembro
- **Auto-análisis**: Generación automática de 10-12 documentos de onboarding a partir del análisis del repositorio
- **Guardarraíles anti-patrón**: Reglas para evitar uso inadecuado de IA durante el onboarding

## Reglas de negocio que implementa

- RN-AUT-01: El buddy IA NO toma decisiones, solo orienta
- RN-ONB-01: Documentación generada en directorio git-ignorado por defecto (puede contener info sensible)

## Relación con otras skills

- **Upstream**: `team-onboarding` (RGPD, evaluación de competencias — esta skill se enfoca en lo técnico)
- **Downstream**: Developer productivo con primer PR aprobado
- **Paralela**: `architecture-intelligence` (el buddy consulta decisiones de arquitectura)

## Decisiones clave

- Se eligió el modelo Manfred v3.0 por su enfoque pragmático y probado en empresas reales
- La documentación se genera en `projects/{proyecto}/onboarding/` git-ignorado, no en el repo público
- El buddy usa la documentación generada como base de conocimiento, no inventa
