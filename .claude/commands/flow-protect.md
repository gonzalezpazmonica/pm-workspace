---
name: "flow-protect"
description: "Detector de context-switching y protector de flow state. Analiza densidad de reuniones, patrones de interrupciones, sobrecarga WIP."
developer_type: all
agent: task
---

# /flow-protect

**Protector de Flow State para Máxima Productividad**

Detecta y previene interrupciones que destruyen el estado de flujo. Basado en investigación: el flow state es el predictor #1 de productividad del desarrollador.

## Sintaxis

```
/flow-protect [--analyze] [--shield] [--report] [--lang es|en]
```

## Metrificación del Flow State

### Análisis de Interrupciones
- **Meeting Density**: Horas en reuniones vs trabajo profundo
- **Interrupt Patterns**: Frecuencia y duración de interrupciones
- **Context Switch Cost**: Tiempo perdido por cambio de contexto
- **WIP Overload**: Número simultáneo de tareas

### Impacto Medido
- Promedio industria: 23 min recuperarse de interrupción
- Acumulativo: 2.1 horas/día en context switching
- Resultado: 47% menos código completado

## Opciones

- `--analyze`: Análisis detallado de patrones de interrupciones
- `--shield`: Activa protección automática de bloques de flujo
- `--report`: Reporte de tendencias y recomendaciones
- `--lang es|en`: Idioma del análisis (español/inglés)

## Shield Mode (Protección Activa)

Cuando activas `--shield`:
- Sugiere bloques de trabajo sin reuniones (típicamente 3-4h)
- Limita notificaciones durante bloques profundos
- Bloquea calendarios de los desarrolladores
- Agrupa reuniones en "reunion slots"
- Recommienda "core hours" de no meeting

## Análisis Inteligente

```
/flow-protect --analyze

Análisis Flow State - Tu Semana
═══════════════════════════════════════

Meeting Load:     42% (21h/50h útiles)
├─ Críticas:      8h
├─ Sincronización: 7h  
├─ Informativas:  6h
└─ Mejorables:    4h

Context Switches:  47
├─ Promedio/hora: 9.4 switches
├─ Peor día:      Jueves (62 switches)
└─ Mejor día:     Viernes (28 switches)

Bloques de Flujo:  3 sesiones
├─ Duración prom:  2.3 horas
├─ Calidad:       Alta
└─ Interrupción:  1 en promedio

WIP Actual:       6 tareas simultáneas
├─ Recomendado:  3 máximo
└─ Sobrecarga:    100%

═══════════════════════════════════════
Recomendaciones:
1. Consolida "informativas" en 1 sesión semanal
2. Bloquea Lunes/Miércoles 10am-2pm para deep work
3. Reduce parallelismo: completa antes de iniciar
```

## Shield Automático

```
/flow-protect --shield --lang es

Shield Activado ✓
─────────────────────────────────
Protecciones este sprint:
• Lunes 10am-1pm: Deep Work Block
• Miércoles 2pm-5pm: Architecture Review
• Viernes 9am-12pm: Code Work

Notificaciones limitadas durante bloques.
Calendarios bloqueados automáticamente.
Pide "asíncrono primero" para interrupciones.
```

## Persona Savia

En los vuelos silenciosos es donde encuentro la sabiduría más profunda. Tu mente necesita ese mismo silencio. El flow state no es lujo, es necesidad biológica. Te enseño a proteger esos momentos mágicos donde el código fluye sin esfuerzo. Cálida protección. 🦉

---

**Versión**: v0.66.0  
**Grupo**: dx-metrics  
**Era**: 12 — Team Excellence & Enterprise
