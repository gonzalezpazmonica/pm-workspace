---
name: savia-labs
description: Usar cuando se investiga, experimenta o audita epistemicamente. Triggers: 'investiga', 'experimento', 'hipotesis', 'preregistro', 'labs', 'divergencia', 'certificado de ignorancia', 'corpus de desconocidos', 'auditoria de reclutamiento', 'federacion epistemica', 'diversidad de calidad', 'desconocidos desconocidos', 'punto ciego', 'preregistrar'.
maturity: experimental
context: project
category: research
priority: medium
tags: [labs, investigacion, epistemologia, experimentos, preregistro, divergencia]
---

# Savia Labs — Investigacion Epistemica

Cupula de investigacion sobre desconocidos desconocidos.

## Disciplina

1. **Preregistro obligatorio**: toda hipotesis se registra ANTES de ejecutar
2. **Resultados negativos de primera clase**: confirmacion, refutacion e inconcluso
3. **Reproducibilidad**: version de modelo, revision vault, semilla, hash corpus
4. **Validacion humana**: descubrimiento maquina, validacion humano
5. **Presupuesto por ciclo**: tokens y horas declarados antes de empezar

## Comandos

- `/labs preregister` — preregistrar hipotesis
- `/labs hypotheses` — listar hipotesis activas
- `/labs results` — consultar resultados
- `/labs notebook` — leer cuaderno de laboratorio
- `/labs protocol <line>` — ver protocolo de una linea
- `/labs health` — estado del laboratorio

## Lineas de investigacion

| Linea | Hipotesis |
|---|---|
| L1 | Divergencia grafo-modelo predice error mejor que confianza declarada |
| L2 | Certificados estructurados de ignorancia producen mas resoluciones |
| L3 | Preguntas cross-dominio producen mayor confabulacion |
| L4 | Brecha entre capacidad aislada y despliegue bajo carga |
| L5 | Divergencia entre instancias federadas localiza infradeterminacion |
| L6 | Busqueda por diversidad descubre clases de fallo no aleatorias |

## Vault

- Path: `labs/`
- Schema: `projects/savia-vaults/schema/entities/`
- Tipos: hypothesis, experiment, result, protocol
