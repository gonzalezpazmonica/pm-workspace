# ADR-002 — Ruta evolutiva: Savia como harness soberano y laboratorio de conformidad

> **Fecha**: 2026-09-26
> **Status**: ACCEPTED
> **Contexto**: auditoría de roadmap 2026-09-26 (roadmap general, Savia Labs, estado real del
> sistema) y *The Executable Enterprise v1.1 — Edición de Ejecución Gobernada* (§12, §19, §22).
> **Decision owner**: operadora (aprobación explícita de las cinco decisiones propuestas).

## Contexto

Convivían tres rumbos incompatibles:

1. La estrategia de 2026-08-02 (documento privado de Savia Labs) planteaba
   Savia como producto para cualquier equipo técnico y priorizaba productizar (federación,
   CLI, web, empaquetado).
2. La ejecución real de agosto-septiembre fue la era *Coherence Before Capability*
   (SE-374..SE-401): cerrar y gobernar el harness.
3. *The Executable Enterprise v1.1* describe Savia como harness soberano y laboratorio de
   ejecución, no como la empresa ni como producto de la tesis (§22, D21).

Además: 18 iniciativas en `IMPLEMENTING` a la vez, 17 documentos de roadmap solapados,
evidencias caducadas en `planning-state.json` y una suite completa con fallos que la CI no
ejecuta. Los fallos graves detectados el mismo día (agentes inutilizables en un frontend,
gates que nunca se ejecutaban) no aparecían en la planificación porque esta medía merges,
no comportamiento.

## Decisión

1. **Naturaleza de Savia.** Savia es el harness soberano y el laboratorio de conformidad
   (Conformance Lab) de The Executable Enterprise. "Producto" significa *harness adoptable por
   equipos técnicos* (instalable, documentado, portable), no plataforma enterprise.
   La estrategia de 2026-08-02 queda **revocada** como rumbo de producto.
2. **Licencia.** Se mantiene la licencia **MIT**. Esta decisión no cambia licencias, avisos ni
   condiciones de distribución.
3. **Ritmo.** La ruta **no tiene fechas ni deadlines**. Cada fase avanza cuando el estado
   anterior es observable, reversible y comprendido (TEE §12). Las estimaciones, si existen,
   son orientativas y nunca compromisos.
4. **WIP.** Máximo **3 iniciativas Savia en `IMPLEMENTING` + 1 línea Labs activa**.
   Lo que sale del foco pasa a `DEFERRED` con fase asignada; lo ya mergeado permanece.
5. **Fuente única.** `docs/propuestas/planning-state.json` es la única fuente de estado;
   `ROADMAP-CURRENT.md` es su vista generada y `docs/ROADMAP.md` abre con esta ruta y conserva
   el historial. Los demás roadmaps quedan marcados como históricos.
6. **SE-401.** Se reescribe alineada a TEE v1.1 (Sufficiency, Commitment, Outcome, Disposition,
   Authority Lease). Ocurre en la Fase B. La colisión de IDs con el programa privado AEK se
   resolvió el 2026-09-26 por decisión de la operadora: AEK usa su propio prefijo (`AEK-`) y los
   IDs `SE-` pertenecen solo a Savia, así que SE-401 conserva su ID.
7. **SE-289 S4.** Sin fecha: vuelve a la cola como un ítem más de la Fase E.

## Ruta (fases con gate de evidencia, sin fechas)

| Fase | Objetivo | Gate de salida |
|---|---|---|
| **A · Verdad y salud** | Fuente única, estados reconciliados, suite en verde o cuarentena explícita con RCA | Suite completa sin fallos no cuarentenados; ≤3 `IMPLEMENTING`; un único roadmap |
| **B · Kernel de gobierno verificable** | Cerrar SE-396; SE-401 v1.1 + frontera AEK↔Savia (F0 de solo lectura); contrato común de Effect Enforcement Point para Claude Code, Codex y OpenCode | SE-396 graduado; SE-401 aprobado; los tres frontends pasan el mismo contrato |
| **C · Conformance Lab (TEE §22)** | Unificar chaos, eval matrix y coherencia en un laboratorio: Bypass Test, escenarios adversariales, invariantes §19.8, replay en cuatro niveles | 0 violaciones de invariantes bajo inyección de fallos en los tres frontends |
| **D · Kernel mínimo y portabilidad** | Ablación SE-400, SAM SE-397 F5/F6, runtime común, portability canaries por frontend y tier | Superficie reducida sin regresión; canaries verdes |
| **E · Harness adoptable** | Instalador, desktop, documentación pública, Vaults adaptativo, SE-289 S4 | Instalación limpia por una persona ajena con doctor en verde |
| **F · Pilotos con evidencia** | Pilotos AEK y experimentos de Savia Labs con datos reales | Sin claims de ROI empresarial sin datos |

Aparcado hasta superar la Fase D: federación y multi-vault, lote enterprise, multi-tenant,
neuro-orquestación, publicación en redes sociales y líneas Labs fuera de la ruta (detalle en Savia Labs, privado).

## Consecuencias

- `planning-state.json`: 3 `IMPLEMENTING` (SE-376, SE-378, SE-396); 15 a `DEFERRED` con fase.
- Nuevas métricas: además de "¿cuántas veces un hallazgo cambió una decisión?",
  "¿cuántos bypass encontró el laboratorio antes que producción?".
- Revisión de esta decisión: cuando se supere el Gate D o si aparece evidencia que contradiga
  el principio de §1.

## Addendum 2026-10-03 — Savia Space como frontend de Savia

> **Decision owner**: operadora (AskUserQuestion, 2026-10-03). Specs: SE-428 y SE-432.

1. **Space es un frontend de Savia, como Claude Code u OpenCode.** Sustituye a la TUI de
   OpenCode y usa `opencode serve` como motor, con la misma configuración, el mismo plugin de
   guards y los mismos agentes, skills y comandos.
2. **No amplía autoridad.**
   - Las herramientas locales solo se ejecutan a través del motor. Los hooks de Savia deciden
     antes: el bus de Space ejecuta los hooks registrados en `.claude/settings.json` con el
     contrato de Claude Code, y el plugin de guards sigue cargado en el motor.
   - Los efectos externos (push, merge, publicación, escritura en Azure DevOps) exigen los mismos
     grants y gates que hoy. Space no los emite ni los relaja.
   - Space nunca aprueba permisos por su cuenta. Desde su interfaz no se aceptan respuestas que
     cambien la configuración persistente del motor.
3. **Modo mediado.** Un hook marcado `blocking: true` que falla o no responde bloquea el
   permiso. En modo interactivo, el comportamiento sigue siendo el de Claude Code (D23-5).
4. **Contrato común.** Space debe pasar el mismo contrato de Effect Enforcement Point que los
   demás frontends cuando exista (Fase B). Hasta entonces, sus escenarios de aceptación son los
   de SE-428.
5. **Excepción de ruta y WIP.**
   - La superficie de escritorio adelanta una parte de la Fase E por mandato de la operadora.
     Ese adelanto no cuenta como progreso de la Fase E ni la desbloquea.
   - El límite pasa **temporalmente a 4 iniciativas Savia en `IMPLEMENTING`**. El cuarto hueco
     es solo para Savia Space (SE-428) y vuelve a 3 al cerrar su 0.2.

