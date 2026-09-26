# ADR-002 — Ruta evolutiva: Savia como harness soberano y laboratorio de conformidad

> **Fecha**: 2026-09-26
> **Status**: ACCEPTED
> **Contexto**: auditoría de roadmap 2026-09-26 (roadmap general, Savia Labs, estado real del
> sistema) y *The Executable Enterprise v1.1 — Edición de Ejecución Gobernada* (§12, §19, §22).
> **Decision owner**: operadora (aprobación explícita de las cinco decisiones propuestas).

## Contexto

Convivían tres rumbos incompatibles:

1. La estrategia de 2026-08-02 (`vaults/SaviaLabs/review/strategy-roadmap-2026-08.md`) planteaba
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
   Authority Lease) y se renombra en Savia para resolver la colisión de ID con el programa AEK,
   sin renumerar el repositorio AEK. Ocurre en la Fase B.
7. **SE-289 S4.** Sin fecha: vuelve a la cola como un ítem más de la Fase E.

## Ruta (fases con gate de evidencia, sin fechas)

| Fase | Objetivo | Gate de salida |
|---|---|---|
| **A · Verdad y salud** | Fuente única, estados reconciliados, suite en verde o cuarentena explícita con RCA | Suite completa sin fallos no cuarentenados; ≤3 `IMPLEMENTING`; un único roadmap |
| **B · Kernel de gobierno verificable** | Cerrar SE-396; SE-401 v1.1 + frontera AEK↔Savia (L31 F0); contrato común de Effect Enforcement Point para Claude Code, Codex y OpenCode | SE-396 graduado; SE-401 aprobado; los tres frontends pasan el mismo contrato |
| **C · Conformance Lab (TEE §22)** | Unificar chaos, eval matrix, coherencia y L28 en un laboratorio: Bypass Test, escenarios adversariales, invariantes §19.8, replay en cuatro niveles | 0 violaciones de invariantes bajo inyección de fallos en los tres frontends |
| **D · Kernel mínimo y portabilidad** | Ablación SE-400, SAM SE-397 F5/F6, runtime común, portability canaries por frontend y tier | Superficie reducida sin regresión; canaries verdes |
| **E · Harness adoptable** | Instalador, desktop, documentación pública, Vaults adaptativo, SE-289 S4 | Instalación limpia por una persona ajena con doctor en verde |
| **F · Pilotos con evidencia** | AEK pilotos, L27 E3/E5, L30 backtest | Sin claims de ROI empresarial sin datos |

Aparcado hasta superar la Fase D: federación y multi-vault, lote enterprise, multi-tenant,
neuro-orquestación, publicación en redes sociales, líneas Labs L24, L25, L29, L12 y L9.

## Consecuencias

- `planning-state.json`: 3 `IMPLEMENTING` (SE-376, SE-378, SE-396); 15 a `DEFERRED` con fase.
- Nuevas métricas: además de "¿cuántas veces un hallazgo cambió una decisión?",
  "¿cuántos bypass encontró el laboratorio antes que producción?".
- Revisión de esta decisión: cuando se supere el Gate D o si aparece evidencia que contradiga
  el principio de §1.
