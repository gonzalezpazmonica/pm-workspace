# Regulatory Compliance -- Dominio

## Por que existe esta skill

Los proyectos de software en sectores regulados (sanidad, finanzas, alimentacion, legal) deben cumplir normativas especificas que varian por industria. Sin deteccion automatica, los equipos descubren requisitos regulatorios demasiado tarde. Esta skill detecta el sector en 5 fases y verifica compliance contra marcos normativos.

## Conceptos de dominio

- **Deteccion sectorial 5 fases**: domain models (35%), naming/routes (25%), dependencies (15%), configuration (15%), docs (10%).
- **12 sectores soportados**: healthcare, finance, food/agriculture, justice/legal, public admin, insurance, pharma, energy, telecom, education, defense, transport.
- **Framework de compliance**: 6 categorias universales (cifrado, audit trails, control acceso, trazabilidad, consentimiento, interoperabilidad).
- **Auto-fix templates**: correcciones automaticas para cifrado, audit log, RBAC, consentimiento, trazabilidad, formatos.
- **Severidad regulatoria**: CRITICAL (riesgo de breach/multa), HIGH (control ausente), MEDIUM (mejora normativa), LOW (best practice).

## Reglas de negocio que implementa

- Score >=55% deteccion automatica; 25-54% preguntar usuario; <25% no regulado.
- Multi-sector posible si multiples sectores puntuan >55%.
- Fixes arquitectonicos requieren Task manual; fixes puntuales son automaticos.
- Re-verificacion obligatoria tras auto-fix para confirmar correccion.

## Relacion con otras skills

- **Upstream**: architecture-intelligence (estructura del proyecto para deteccion).
- **Downstream**: governance-enterprise (hallazgos alimentan matriz de controles), compliance-report (informe ejecutivo).
- **Paralelo**: adversarial-security (seguridad tecnica vs esta skill de compliance normativo).

## Decisiones clave

- Deteccion ponderada 5 fases sobre keywords simples: reduce falsos positivos significativamente.
- References por sector cargados bajo demanda: solo el sector detectado consume contexto.
- Auto-fix con re-verificacion sobre fix-and-forget: garantiza que la correccion realmente resuelve el gap.
