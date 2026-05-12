# Regla: Revisar flujos existentes antes de improvisar

> **REGLA INMUTABLE** — Antes de ejecutar cualquier acción operativa (push, PR,
> commit, firma, release, deploy, scan), revisar si existe un comando/skill/script
> canónico que ya gestiona el flujo. Improvisar tool-calls equivalentes está
> prohibido — duplica lógica, salta gates y oculta side-effects.
>
> **Pattern alignment**: implementa Genesis **B9 GOAL STEWARD** + Rule #17
> (anti-improvisación) — ver `docs/rules/domain/attention-anchor.md`.

---

## Principio

El workspace tiene >540 comandos y >90 skills. Cada flujo crítico (PR, commit,
push, firma, weekly-report, project-update) está **encapsulado**. Si Savia
ejecuta los pasos a mano:

- Salta gates de seguridad embebidos (signature, force-push guard, PII scan).
- Duplica lógica que ya está probada y mantenida.
- Genera divergencia entre lo que hace Savia y lo que hace el equipo humano.
- Esconde side-effects (memoria, telemetría, audit-log).

## Protocolo obligatorio antes de cualquier acción operativa

```
1. Identificar el verbo de la acción (push, sign, commit, deploy, audit, ...)
2. Buscar comando canónico:
     glob .opencode/commands/*{verbo}*
     glob .claude/commands/*{verbo}*
3. Buscar skill canónica:
     glob .opencode/skills/**/SKILL.md  + grep {verbo}
4. Buscar script canónico:
     glob scripts/*{verbo}*
5. SI EXISTE → leerlo completo (no resumido) y usarlo.
6. SI NO EXISTE → declarar explícitamente "no existe flujo canónico para X"
                  antes de improvisar, y crear uno si la acción se repite ≥2.
```

## Prohibido

- Lanzar `git push` directo cuando existe `/pr-plan` o `push-pr.sh`.
- Lanzar `git commit` ignorando `commit-guardian`.
- Firmar a mano cuando hay `confidentiality-sign.sh`.
- Ejecutar pasos sueltos cuando hay un comando que los orquesta.
- Decir "voy a leerlo" después de haber improvisado — el orden es leer primero.

## Auto-corrección

Si Savia detecta que ha improvisado un flujo que ya existía:

1. Parar inmediatamente.
2. Leer el flujo canónico.
3. Persistir la lección en `tasks/lessons.md` (Rule #21).
4. Actualizar `docs/flow-map.md` si el flujo no estaba indexado.

## Mapa de flujos

Índice canónico de flujos operativos: `docs/flow-map.md`. Mantener actualizado
ante cualquier flujo nuevo o renombrado.
