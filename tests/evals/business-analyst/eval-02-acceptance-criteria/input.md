# Eval 02 — Extracción de criterios de aceptación desde reglas de negocio ambiguas

## Contexto

El departamento de operaciones de TrazaBios ha documentado las reglas de negocio
para el proceso de aprobación de lotes de producción. La documentación es informal
y ambigua. El business-analyst debe extraer criterios de aceptación precisos y
verificables para el sistema que automatizará parte del proceso.

## Reglas de negocio informales (entrada)

"Un lote puede aprobarse cuando todos los controles de calidad han pasado.
Si hay algún control que ha fallado pero es de nivel bajo, se puede aprobar
con una excepción si un supervisor lo autoriza. Los controles críticos nunca
se pueden aprobar con excepción. Cuando un lote se aprueba se le asigna un
número de certificado único. Los lotes rechazados tienen que pasar por un
proceso de revisión antes de poder intentarlo de nuevo. Un técnico no puede
aprobar su propio lote. El supervisor no puede aprobar lotes de su propio equipo."

## Tarea para el agente business-analyst

Extrae criterios de aceptación formales (Given/When/Then) a partir de las reglas
de negocio informales anteriores. Para cada criterio:
- Identificador único (AC-NNN)
- Formato Given/When/Then estricto
- Clasificación por tipo: flujo nominal, flujo alternativo, regla de negocio, restricción
- Identificar las ambigüedades encontradas y la decisión tomada para resolverlas

Debe identificar al menos: aprobación nominal, aprobación con excepción,
rechazo por control crítico, restricción del técnico propio, restricción del supervisor.
