# Eval 03 — Modelado de reglas de dominio para cálculo de tarifas

## Contexto

El proyecto PM-Workspace necesita un módulo de cálculo de tarifas para servicios
de consultoría. Las tarifas varían según el tipo de servicio, el perfil del
profesional, el volumen contratado y los descuentos aplicables. El business-analyst
debe modelar las reglas de dominio antes de que el arquitecto diseñe las entidades.

## Descripción del negocio

Los servicios de consultoría se clasifican en tres categorías: Standard, Premium
y Enterprise. Cada categoría tiene una tarifa base por hora. Los profesionales
tienen tres perfiles: Junior (multiplicador 1.0), Senior (multiplicador 1.5) y
Principal (multiplicador 2.0). El precio final por hora es: tarifa_base x multiplicador.

Los descuentos por volumen se aplican sobre el total del contrato: 0% para contratos
menores de 100 horas, 5% entre 100 y 499 horas, 10% entre 500 y 999 horas, y 15%
para contratos de 1000 horas o más. Los descuentos no son acumulables con otros
descuentos especiales. Los contratos Enterprise tienen un mínimo de 500 horas.

Si un cliente tiene facturas vencidas con más de 30 días de retraso, no puede
contratar nuevos servicios hasta regularizar su situación.

## Tarea para el agente business-analyst

Modela las reglas de dominio anteriores produciendo:
1. Glosario de términos del dominio (entidades, valores, conceptos clave)
2. Reglas de negocio numeradas con precondiciones y postcondiciones
3. Casos límite identificados (valores en los bordes de los rangos)
4. Invariantes del dominio (condiciones que nunca pueden violarse)
5. Al menos 3 preguntas de clarificación que haría al cliente antes de implementar
