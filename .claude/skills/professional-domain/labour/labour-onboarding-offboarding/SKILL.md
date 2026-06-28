---
name: labour-onboarding-offboarding
description: "Genera checklists y documentación de onboarding/offboarding laboral con plazos duros (alta SS antes de empezar, baja SS 3 días, finiquito). Alertas de caducidad incluidas."
summary: |
  Produce checklists de entrada/salida de trabajadores con plazos legales exactos,
  alertas de sanciones TGSS, borradores de documentos (contrato, finiquito, certificado
  empresa) y timeline en días. SIEMPRE señala que el alta SS debe ser previa al inicio
  de la actividad laboral. Requiere validación por graduado social.
maturity: stable
context: isolated
context_cost: medium
category: "professional-domain/labour"
tags: ["onboarding", "offboarding", "alta-SS", "finiquito", "TGSS", "SEPE", "contrato", "ES"]
priority: "high"
---

# labour-onboarding-offboarding — Gestor de Documentación de Entrada/Salida

## Cuándo usar esta skill

- Al contratar un nuevo trabajador (alta en Seguridad Social, contrato, IRPF).
- Al tramitar la salida de un trabajador (baja SS, finiquito, certificado empresa).
- Para verificar que los plazos legales de alta/baja se están cumpliendo.
- Para calcular el finiquito de un trabajador que causa baja.
- Para generar un checklist completo de onboarding o offboarding con timeline.

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `proceso` | Tipo de proceso | `ONBOARDING` o `OFFBOARDING` |
| `perfil_empleado` | Datos del trabajador | Nombre, categoría, tipo contrato, jornada |
| `contexto_empresa` | Datos de la empresa | CIF, sector, convenio, RETA o cuenta de cotización |
| `fecha_inicio` o `fecha_baja` | Fecha clave del proceso | `2026-07-01` |

## Inputs opcionales

| Campo | Descripción |
|---|---|
| `causa_baja` | Despido / dimisión / fin contrato / mutuo acuerdo / jubilación |
| `salario_bruto` | Para calcular finiquito y liquidación |
| `vacaciones_pendientes` | Días no disfrutados |
| `pagas_extra` | Número y si están prorrateadas o no |
| `requisitos_especificos` | Necesidades de la empresa (seguro de vida, vehículo, etc.) |

## Outputs producidos

1. **Checklist con plazos** — tareas ordenadas por fecha límite con alertas de caducidad
2. **Alertas de sanciones** — consecuencias de incumplir plazos duros (TGSS, SEPE, IRPF)
3. **Borradores de documentos** — contrato (onboarding) o finiquito/certificado empresa (offboarding)
4. **Timeline visual** — secuencia de días desde la fecha de inicio/baja
5. **Notas de compliance** — obligaciones específicas por tipo de contrato o causa de baja
6. **Disclaimer laboral** — obligatorio al final

## Outputs excluidos

- Tramitación efectiva ante TGSS, SEPE o AEAT (requiere acceso a sistemas)
- Cálculo de cuotas de Seguridad Social (depende de bases de cotización y tipo de contrato)
- Asesoramiento sobre tipo óptimo de contrato para cada caso específico

## Alerta inmutable (onboarding)

En todo proceso ONBOARDING, emitir siempre en posición destacada:

```
ALERTA CRÍTICA — ALTA SS:
El alta en la Seguridad Social (Sistema RED o SEDESS) debe realizarse
ANTES del inicio de la actividad laboral, con el trabajador aún no incorporado.
Un trabajador que empieza sin alta previa constituye una infracción muy grave
de la LISOS (art. 22.2), con sanción de 6.251 € a 187.515 € por trabajador.
Además, en caso de accidente laboral sin alta previa, la empresa asume la
responsabilidad directa de todas las prestaciones.
```

## Relación con otras skills

- **Upstream**: `labour-document-drafter` (carta de despido ya redactada antes del offboarding)
- **Downstream**: `labour-conflict-resolver` (si el offboarding genera conflicto posterior)
- **Paralelo**: `labour-convention-analyzer` (verificar plazos del convenio para finiquito)

## Ver también

- `DOMAIN.md` — plazos duros de alta/baja, componentes del finiquito, tipos de contrato
- `prompt.md` — instrucciones de generación para el modelo
