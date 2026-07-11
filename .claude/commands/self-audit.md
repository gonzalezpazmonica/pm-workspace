---
name: self-audit
description: Auto-auditoria mensual — ejecuta bateria de checks, muestreo de regresion y registra hallazgos.
tier: extended
---

# /self-audit

Ejecuta la bateria completa de checks declarada en `config/self-audit-battery.yaml`
con muestreo de regresion sobre specs archivados.

## Flujo

1. Cargar bateria desde `config/self-audit-battery.yaml`
2. Ejecutar checks en orden: critical → high → medium
3. Ejecutar muestreo de regresion (3 specs aleatorios de `specs-archive/`)
4. Para cada hallazgo confirmado: sugerir entrada `error_reconocido` en el ledger
5. Presentar informe agregado con severidades

## Opciones

- `--quick`: omite checks de severidad medium
- `--check ID`: ejecuta solo el check especificado

## Cadencia

Programado mensualmente. Invocable a demanda via `/self-audit`.

## Bateria actual

Ver `config/self-audit-battery.yaml` para la lista completa de checks.
