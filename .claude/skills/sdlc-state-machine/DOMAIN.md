# Dominio: sdlc-state-machine

## Entidades Clave

- **Task/PBI:** Elemento de trabajo en el ciclo de vida
- **State:** Estado actual en la máquina de estados
- **Gate:** Condición que debe cumplirse para transición
- **Actor:** Usuario que ejecuta la transición
- **Audit Trail:** Registro histórico de todas las transiciones

## Conceptos

**Estado:** Punto discreto en el ciclo de vida de desarrollo

**Transición:** Movimiento de un estado a otro (validado por puertas)

**Puerta:** Condición evaluable que permite o bloquea transición

**Política:** Conjunto de puertas por proyecto (configurable)

**Trazabilidad:** Registro completo para cumplimiento y auditoría

## Relaciones

- Una Tarea tiene un Estado actual
- Un Estado permite múltiples Transiciones
- Cada Transición requiere múltiples Puertas
- Las Puertas se configuran por Política de Proyecto
- Todo cambio se registra en Auditoría
