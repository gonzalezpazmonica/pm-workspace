---
name: "deep-work"
description: "Planificador de bloques de trabajo profundo basado en calendario y carga. Framework de Cal Newport aplicado a equipos de desarrollo."
developer_type: all
agent: task
---

# /deep-work

**Planificador de Trabajo Profundo para Máxima Calidad**

Protege bloques de trabajo profundo basados en tu calendario y carga de sprint. Framework de Cal Newport: cómo reclamar el tiempo necesario para trabajo que requiere máxima concentración (3-4 horas mínimo sin interrupciones).

## Sintaxis

```
/deep-work [--plan] [--track] [--optimize] [--lang es|en]
```

## Opciones

- `--plan`: Genera plan de bloques profundos para la próxima semana
- `--track`: Registra sesiones completadas (calidad + interrupciones)
- `--optimize`: Analiza bloques y propone mejoras
- `--lang es|en`: Idioma del plan

## /deep-work --plan

Crea bloques de 3-4h basados en:
- Tu calendario (detecta gaps, elimina conflictos)
- Carga de sprint (prioriza tareas complejas)
- Tipo de trabajo (profundo vs. shallow)
- Patrones de energía personal

Output: Plan semanal con bloques protegidos, notificaciones apagadas, Slack en modo "no disponible".

## /deep-work --track

Registra calidad de cada sesión:
- ¿Cuántas horas completaste?
- ¿Cuántas interrupciones tuviste?
- ¿Calidad de flujo? (1-10)

Calcula eficiencia: (horas - interrupciones × 23min) / horas.

Histórico últimas 5 sesiones + insights sobre caídas de productividad.

## /deep-work --optimize

Analiza 6 sprints anteriores:
- Duración promedio (target: 3-4h)
- Interrupciones por sesión (target: <1)
- Calidad de flujo (target: 8+/10)
- Eficiencia general (target: >90%)

Compara contra benchmarks de ingeniería. Propone:
1. Extender duración si es <3h
2. Reducir interrupciones (focus mode, OOO)
3. Proteger una sesión de 4h semanal
4. Concentrar en ventana matutina

Plan de 1 mes: Semana a semana cómo alcanzar 8.5/10 calidad.

## Integración

Detecta automáticamente tu calendario (Outlook/Google), gaps libres, patrones de reuniones, ventanas óptimas.

Costo de prevención: sin bloques profundos, features complejas multiplican su duración 2-3x.

## Persona Savia

El trabajo profundo es donde brillas. Vi que tienes 8 interrupciones en una "sesión" de 2 horas. Eso es ruido. Te enseño a reclamar ese tiempo sagrado. Cal Newport lo llama superpoder. 🦉

---

**Versión**: v0.66.0 | **Grupo**: dx-metrics | **Era**: 12 — Team Excellence & Enterprise
