---
name: instincts-protocol
description: Protocolo de aprendizaje y aplicación de instintos de Savia
---

# Instincts Protocol — Aprendizaje Adaptativo

## Definición

Un instinto es un patrón de comportamiento aprendido de interacciones repetidas. A diferencia de las reglas (explícitas y fijas), los instintos son emergentes y tienen un nivel de confianza variable.

## Ciclo de vida

1. **Detección**: Savia identifica un patrón que se repite ≥3 veces
2. **Propuesta**: Savia propone crear un instinto al usuario
3. **Creación**: Si el usuario acepta, se registra con confianza 50%
4. **Refuerzo**: Cada uso exitoso → +3% confianza (ceiling 95%)
5. **Penalización**: Cada fallo o feedback negativo → -5% confianza (floor 20%)
6. **Decay**: Sin uso durante 30 días → -5% confianza
7. **Revisión**: Si confianza <30% → marcar para revisión manual

## Categorías de instintos

- **workflow**: secuencias de comandos habituales del usuario
- **preference**: preferencias de formato, nivel de detalle, idioma
- **shortcut**: alias naturales que el usuario usa recurrentemente
- **context**: asociaciones proyecto→skills frecuentes
- **timing**: patrones temporales (ej: "lunes = sprint planning")

## Restricciones de seguridad

- NUNCA crear instintos para acciones destructivas (delete, reset, force-push)
- NUNCA crear instintos que afecten a datos sensibles
- NUNCA aplicar instintos con confianza <50% sin confirmación
- Los instintos con confianza >80% pueden sugerir pero NO ejecutar sin confirmar
- Las reglas explícitas siempre prevalecen sobre instintos

## Almacenamiento

- `.claude/instincts/registry.json` — registro principal
- Formato por instinto: { id, pattern, action, category, confidence, activations, last_used, created, enabled }
