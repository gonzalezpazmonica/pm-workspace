---
name: prompt-optimizer-auto-trigger
description: Protocolo para activar skill-optimize automaticamente tras uso de agentes
---

# Auto-Trigger de Optimizacion de Prompts

## Principio

Cada vez que un agente se ejecuta, Savia registra una "ejecucion" en el log
del agente. Cuando un agente acumula suficientes ejecuciones con feedback
implicito (correcciones del PM, re-ejecuciones, quejas), Savia sugiere
ejecutar `/skill-optimize` sobre ese agente.

## Señales de que un agente necesita optimizacion

### Señales explicitas (alta confianza)
- PM corrige output del agente manualmente despues de ejecucion
- PM dice "esto no es lo que esperaba" o "hazlo de otra forma"
- PM re-ejecuta el mismo agente con instrucciones modificadas
- PM edita el fichero .md del agente directamente

### Señales implicitas (media confianza)
- El agente se ejecuta 5+ veces sin que el PM adopte el output tal cual
- El agente consistentemente genera outputs que superan 150 lineas
- El agente no actualiza _digest-log.md cuando deberia (digest agents)
- El agente produce outputs que el coherence-validator puntua < 6/10

## Cuando sugerir

Tras detectar 3+ señales en las ultimas 10 ejecuciones del agente:

```
💡 El agente {nombre} ha necesitado correcciones en 3 de sus ultimas 10 ejecuciones.
   ¿Quieres que lo optimice? → /skill-optimize {nombre}
   Necesitare un input de prueba y un checklist de criterios.
```

## Auto-generacion de test fixtures

Cuando Savia sugiere optimizacion, puede proponer un fixture basado en:
1. El ultimo input real que se le paso al agente (si no es confidencial)
2. Los criterios que el PM uso para corregir (convertidos a checklist)
3. El output corregido por el PM como "gold standard"

Ejemplo:
```yaml
# Auto-generated from last 3 executions of meeting-digest
name: "fixture-from-usage"
input: "projects/trazabios/team/one2one/one2one-sergio-monica.vtt"
checklist:
  - id: CHK-01
    criterion: "Extrae nombre completo de la persona entrevistada"
    weight: 2
    source: "PM corrigio nombre incorrecto en ejecucion 2026-03-17"
  - id: CHK-02
    criterion: "Resuelve homonimos (3 Sergios) correctamente"
    weight: 3
    source: "PM edito output para cambiar Sergio Martin por Sergio Lopez"
  - id: CHK-03
    criterion: "Actualiza TEAM.md tras digestion"
    weight: 2
    source: "PM pidio actualizacion manual que debio ser automatica"
```

## Integracion con agent-trace

El hook `agent-trace-log.sh` ya registra ejecuciones de agentes.
Extender para capturar:
- Resultado: adoptado_tal_cual | editado_por_pm | descartado | re-ejecutado
- Tiempo entre ejecucion y siguiente accion del PM
- Si el PM edito el output del agente (Edit tool en fichero de output)

## Cadencia de sugerencia

- NUNCA sugerir optimizacion durante ejecucion de un agente
- Sugerir al final de una sesion si hay agentes con señales acumuladas
- Maximo 1 sugerencia por sesion (no bombardear)
- Si el PM rechaza la sugerencia, no repetir en 5 sesiones

## Prioridad de optimizacion

Cuando hay multiples agentes candidatos, priorizar por:
1. Frecuencia de uso (mas usado = mas impacto)
2. Tasa de correccion (mas corregido = mas necesitado)
3. Complejidad del agente (digest > developer > operator)
