# PRD — Product Requirements Document

## PBI: {PBI_ID} — {PBI_TITLE}
## Proyecto: {PROJECT_NAME}
## Fecha: {DATE}
## JTBD asociado: `discovery/PBI-{PBI_ID}-jtbd.md`

---

## 1. Resumen ejecutivo

[1-3 frases: qué se va a construir, para quién y por qué importa]

---

## 2. Problema

[Descripción del problema que el usuario experimenta hoy. Basado en el JTBD.]

---

## 3. Objetivos del producto

| # | Objetivo | Métrica de éxito |
|---|---|---|
| 1 | [Qué queremos lograr] | [Cómo sabemos que lo logramos] |
| 2 | [Qué queremos lograr] | [Cómo sabemos que lo logramos] |

---

## 4. Requisitos funcionales

Basados en los criterios de éxito del JTBD y los criterios de aceptación del PBI:

| # | Requisito | Prioridad | Fuente |
|---|---|---|---|
| RF-1 | [Requisito] | Must | PBI / JTBD |
| RF-2 | [Requisito] | Must | PBI / JTBD |
| RF-3 | [Requisito] | Should | JTBD |
| RF-4 | [Requisito] | Could | Análisis |

Prioridades: **Must** (sin esto no se entrega) · **Should** (importante) · **Could** (nice to have)

---

## 5. Requisitos no funcionales

| # | Requisito | Detalle |
|---|---|---|
| RNF-1 | Rendimiento | [Ej: Respuesta < 200ms para listados paginados] |
| RNF-2 | Seguridad | [Ej: Solo usuarios autenticados con rol X] |
| RNF-3 | Escalabilidad | [Ej: Soportar hasta N registros simultáneos] |

---

## 6. Fuera de scope

Lo que explícitamente NO se incluye en este PBI:

1. [Lo que no se hace y por qué]
2. [Lo que queda para un PBI futuro]

---

## 7. Dependencias

| Dependencia | Tipo | Estado |
|---|---|---|
| [PBI o módulo] | Bloqueante / Informativa | Resuelta / Pendiente |

---

## 8. Riesgos identificados

| # | Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | [Riesgo] | Alta/Media/Baja | Alto/Medio/Bajo | [Plan] |

---

## 9. Criterios de aceptación (formalizados)

Basados en el PBI original y enriquecidos con el análisis JTBD:

```gherkin
Scenario: [Nombre del escenario]
  Given [contexto]
  When [acción del usuario]
  Then [resultado esperado]
```

---

## 10. Aprobación

- [ ] Product Owner / Stakeholder confirma los requisitos
- [ ] Business Analyst valida la coherencia con reglas de negocio
- [ ] Listo para pasar a `architect` y `pbi-decompose`

---

*Generado por business-analyst · Fuente: PBI {PBI_ID} + JTBD · No incluye estimaciones de tiempo*
