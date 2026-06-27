---
context_tier: L2
token_budget: 820
spec: SE-228
slice: S2
---

# Maker/Checker Split Protocol — SE-228 S2

> **REGLA OBLIGATORIA en L2+** — El agente que implementa NO puede marcar su
> propio trabajo como "done". Implementa el patron anti-"Verifier Theater"
> del catalogo cobusgreyling/loop-engineering (MIT, 2026-06).

## Principio

**El implementer propone; el checker verifica desde posicion adversarial.**
Ninguna instancia de agente tiene autoridad para validar su propio output.
La separacion es estructural, no opcional.

## Invariantes

1. **Implementer propone — solo puede abrir PRs en Draft, nunca aprobar ni mergear.**
   El agente que escribe el codigo no tiene permisos de merge. Todo output
   es una propuesta pendiente de revision externa.

2. **Verifier es separado — instancia de agente distinta, instrucciones distintas.**
   El verificador recibe el diff/worktree con contexto limpio, sin el hilo
   de conversacion del implementer. Debe poder operar en frio.

3. **Verifier stance: default REJECT — aprueba solo si tests pasan Y scope minimo Y no hay regresiones.**
   La postura por defecto es el rechazo. La carga de la prueba esta en el
   implementer: los tests deben pasar, el scope debe ser el minimo necesario,
   y no debe haber regresiones detectables.

4. **Si verifier no disponible: escalar a humano, no auto-aprobar.**
   La ausencia de verificador no habilita auto-aprobacion. El loop se pausa
   y escala al revisor humano configurado en AUTONOMOUS_REVIEWER.

5. **Verificacion incluye: ejecutar tests, revisar archivos tocados, confirmar scope minimo.**
   El verificador no puede hacer rubber-stamp. Debe ejecutar la suite de tests,
   revisar que solo se tocaron los archivos declarados en el scope, y confirmar
   que no se introdujeron cambios fuera del scope.

## Niveles de aplicacion

| Nivel | Aplicacion |
|-------|------------|
| L0    | No aplica (modo report-only, sin cambios) |
| L1    | Recomendado — el humano actua como checker |
| L2    | **Obligatorio** — checker automatico o humano antes de merge |
| L3    | **Obligatorio** — checker automatico + aprobacion humana final |

Ver docs/rules/domain/loop-phasing.md para definicion completa de niveles L0-L3.

## Script de apoyo

scripts/loop-verify.sh genera el prompt adversarial estructurado para el
verificador. NO ejecuta Claude automaticamente (requeriria L3 con aprobacion).
Genera el prompt listo para que el humano lo pase a un agente controlado.

```bash
# Uso tipico
bash scripts/loop-verify.sh \
  --worktree /ruta/al/worktree \
  --skill overnight-sprint \
  --spec docs/propuestas/SE-228-loop-engineering-patterns.md

# Dry-run: muestra el prompt sin ejecutar sub-agente
bash scripts/loop-verify.sh --worktree . --skill overnight-sprint --dry-run
```

## Fallo del patron: Verifier Theater

El anti-patron ocurre cuando el verificador es la misma instancia con las
mismas instrucciones que el implementer, o cuando el verificador siempre
aprueba sin ejecutar tests. Sintomas:

- Verificador aprueba en < 10 segundos
- Tests no se ejecutan durante la verificacion
- Scope drift no detectado (archivos fuera del scope modificados)
- Misma conversacion usada para implementar y verificar

## Referencias

- docs/rules/domain/autonomous-safety.md — Gates de seguridad obligatorios
- docs/rules/domain/loop-phasing.md — Niveles L0-L3 (SE-228 S5)
- scripts/loop-verify.sh — Script de apoyo para prompt adversarial
- SE-228 spec: docs/propuestas/SE-228-loop-engineering-patterns.md
