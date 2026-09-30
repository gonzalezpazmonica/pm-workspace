# Recopilación de roadmaps — 2026-09-30

Estado: síntesis solicitada por la operadora. Ruta vigente: [ROADMAP](ROADMAP.md);
estado y cola: [planning-state](propuestas/planning-state.json); decisión: [ADR-002](decisions/adr-002-ruta-evolutiva-harness-conformance-lab.md).
Snapshot público `88aac851ff6692bd0d333d903d93837c923dd968`;
`git fetch origin` y comparación `HEAD...origin/main`: 0/0. Después se integran
SE-420 (#1200), SE-421 (#1201) y SE-422 (#1202) hasta `c9b42de5`.

## Alcance y método

Inventario por nombres de roadmap/plan de desarrollo, lecturas y referencias
cruzadas en `docs/`, `.claude/`, `projects/`, `zeroclaw/` y cúpula SaviaLabs por
MCP. **35 documentos de roadmap/planes**: 19 del workspace, 2 de SaviaClaw/voz
y 14 de Labs. También se consultan planning-state, ADR-002, estrategia AST,
instrucciones de proyecto, log de commits y evidencia/handoff de cierre.
Los planes contienen tareas incrustadas: este inventario no certifica cada spec
ni la vigencia de cada checkbox. Las traducciones no son iniciativas adicionales.

Se excluyen fixtures de tests, comandos, runners y changelog: describen o prueban
el roadmap. Nueve traducciones localizadas (robótica EN y AST EN/EU/DE/GL/FR/PT/IT/CA)
se agrupan con su original; no se ha revalidado su equivalencia semántica.
AEK se resume por su frontera autorizada en Labs, sin publicar su backlog privado.

## Fuentes públicas y decisión de consolidación

| Fuente | Papel/estado observado | Destino del trabajo pendiente |
|---|---|---|
| [docs/ROADMAP](ROADMAP.md) | Ruta A–F y eras históricas | Actualizada; entrada general |
| [ROADMAP-CURRENT](propuestas/ROADMAP-CURRENT.md) | Vista generada | Estado + cola de sesiones canónicos |
| [ROADMAP de propuestas](propuestas/ROADMAP.md) | Histórico; antiguo «canónico» | No ejecutar sus tiers; cierre factual A, higiene D/E |
| [Unificado abril](propuestas/ROADMAP-UNIFIED-20260418.md) | SUPERSEDED | Patrón y antecedentes; no nueva cola |
| [Unificado agosto](propuestas/ROADMAP-UNIFIED-20260827.md) | Histórico; mezcla entregas y pendientes | Reutilizar SE-338/339/344, cúpulas y retornos; no rehacer batches |
| [Superpowers](propuestas/SAVIA-SUPERPOWERS-ROADMAP.md) | SUPERSEDED | Retornos históricos, no nuevos PRs |
| [Context Intelligence](propuestas/SPEC-011-context-intelligence-roadmap.md) | IMPLEMENTED; cuerpo todavía ACTIVE | Histórico; memoria/recall ya tienen retornos posteriores |
| [SaviaClaw autonomía](propuestas/SPEC-010-saviaclaw-autonomy-roadmap.md) | ARCHIVED; cuerpo ACTIVE | Hardware y demanda tras Gate D |
| [SaviaDivergent](propuestas/SPEC-062-saviadivergent-roadmap.md) | PROPOSED, diferido por investigación | Aparcado según ADR-002; no rebajar privacidad/accesibilidad vigente |
| [SCL](SCL-ROADMAP.md) | Histórico; mecanismos entregados | Reutilización; medición real en C/F, no duplicar bucle |
| [SAGI](sagi-roadmap.md) | Histórico; cierre de línea y futuros mezclados | Mantener retornos; reevaluaciones con datos en F |
| [Savia Models](savia-models/ROADMAP-IMPROVEMENTS.md) | Baseline abril, sin recertificación actual | Hallazgos de seguridad a contrastar en A; calidad D, adopción E |
| [SE-395/396 handoff](specs/SE-395-396-luna-roadmap.md) | Plan histórico de ejecución | Evidencia más reciente domina; integridad B, adaptativo E |
| [Enterprise](ENTERPRISE_ROADMAP.md) | Histórico | Arquitectura empresarial aparcada; identidad mínima se diseña separadamente |
| [Enterprise Development](propuestas/savia-enterprise/DEVELOPMENT-PLAN.md) | ARCHIVED; ondas y «live» antiguos | Fuera de ruta; sin cambio de MIT, paralelismo o alcance |
| [Robótica](robotics-roadmap.md) | Histórico | Seguridad existente se conserva; ampliación requiere hardware y demanda |
| [Savia Web](../projects/savia-web/ROADMAP.md) | Snapshot marzo | Contrastar ACL y entregas; regresión/adopción E; collab/PWA por demanda |
| [Web Git Manager](../projects/savia-web/specs/roadmap-git-manager.md) | Calendario marzo; contradice estado ACL de Web | Contraste antes de construir; no activar Git write por ese calendario |
| [.claude roadmap](../.claude/savia-roadmap.md) | MOVED/archivado | Redirección a ruta vigente |
| [SaviaClaw](../zeroclaw/ROADMAP.md) | Plan de componente; hardware por verificar | Aparcado; no asumir tests físicos ejecutados |
| [Voz](../zeroclaw/docs/voice-next-gen-roadmap.md) | v2 entregada vs v2.5/v3 propuesta | Media/archivos comparten contratos con Files; tiempo real/hardware por demanda |

[Estrategia AST](ast-strategy.md) es diseño transversal, no una cola adicional:
comprensión/gates/mapas alimentan SE-376/397/400 y se contrastan antes de ampliar.

## Fuentes Labs (detalle privado en la cúpula)

Las 14 fuentes leídas son: ROADMAP, CYCLE_PLAN, plan SAGI y los 11 roadmaps
L13, L28, L29, L30, L31, L32, L33 base, L33 ampliación, L34, L35 y ruta
transversal Savia/AEK/AEOS. Inventario exacto, pendientes y motivos en
`labs/roadmaps/20260930-roadmap-consolidation.md` de SaviaLabs, accesible por MCP.

Se contrastan además cuatro antecedentes de planificación incrustada de Labs:
negocio, founder, arquitectura L27 y programa de robótica. Su calendario,
financiación y plataforma no desplazan ADR-002; requieren demanda/piloto y
verificación de premisas. Un índice privado adicional se consulta sólo como
puntero: su contenido sensible no se reproduce aquí ni en la nueva nota N2.

| Grupo | Aportación a la ruta general |
|---|---|
| Labs global/ciclo y L14/L28 | Integridad, calidad y ablación A/B/D; WIP=1 |
| SAGI/L13; L1–L10 y L17–L23 referidos por el índice | Reutilizar retornos; separar validación sintética de beneficio operacional |
| L31 | Frontera AEK READ_ONLY en B; namespace AEK- resuelto, no decisión abierta |
| L32 | Evaluación/operación y cierres RAG; pendientes permanecen sólo en Labs |
| L33 base/ampliación | Seguridad del existente A; contexto/serving y perfiles en E con gates |
| L34 | Identidad mínima Vaults priorizada por seguridad; SSO/federación posteriores |
| L35/ruta transversal | Diseño coordinador AEOS y pilotos F; ninguna activación implícita |
| L30 | Prospectiva/backtest con corpus real F; escenarios no son predicciones verificadas |
| L29/RBT, L24/L25, L12, L9, L26/L27 referidos | Demanda/hardware/piloto; aparcados o condicionados, conservando entregas |

## Contradicciones resueltas para la planificación

1. A aún nombraba SE-378: #1187 la sustituye por SE-407. Se conserva el WIP
   SE-407/376/396; una aprobación no equivale a estar IMPLEMENTING.
2. SE-410–422 y SE-402–405 tienen entregas integradas (SE-420–422 tras el snapshot). Se registra `delivery`,
   sin `completion` inventado ni cierre humano supuesto; revisar antes de rehacer.
3. H04 ya tiene implementación #1183, sin ejecución real. El handoff y el
   informe del 28/09 son inputs de revalidación; no un baseline global certificado.
4. Deuda 128/137 corresponde al 27/09. #1173/#1180 son avances, no nueva medida
   ni cierre de wave; se mantiene el ratchet y pruebas certificadas ≥80.
5. Labs mantiene varias cabeceras de «vigente» y deltas Files ya integrados
   como pendientes. Se añade un índice actual y se fecha el contenido histórico.
6. Login/PAT no concede autoridad AEK. Archivos/contexto, principal y efectos
   requieren contratos distintos y compatibles, sin nuevo issuer.
7. Scores, horas, vulnerabilidades y fechas de planes antiguos son antecedentes,
   no medidas actuales. Un hallazgo antiguo de seguridad exige reproducción.

## Criterios y lectura para próximas sesiones

Orden obligatorio: autoridad/seguridad → fase/gates/WIP → necesidad/urgencia →
valor/desbloqueos → esfuerzo/incertidumbre. Desempate: cerrar evidencia existente
y reducir superficie antes de ampliar. Un slice grande se divide por salida
verificable. Si falta un gate, preparar el paquete de revisión y continuar
otro trabajo autorizado del WIP; no iniciar una cuarta iniciativa.
SE-406 Relay baja a P3 dentro de B: decisiones abiertas y demanda por verificar;
no desplaza el núcleo ni autoriza mensajes. SE-405 observabilidad queda P2;
SE-376 tiene P0 explícita para hacer fiable la evidencia de la ruta.

Cada entrada S01–S09 de `route.session_plan` contiene prioridad, fase, IDs,
necesidad, urgencia, valor, dependencias, esfuerzo, entrada y salida.
Consultar `bash scripts/roadmap.sh current` para la cola completa y
`next` para el trabajo compatible con fase/WIP. Revalidar HEAD y fuentes al
inicio; registrar evidencia y siguiente paso al terminar. Sin deadlines.

Confianza alta en commits y estados leídos; limitada en utilidad operacional,
esfuerzo residual y datos privados no publicados. No se ejecutan aquí canaries,
pilotos, escáner real ni toda la suite de producto para declarar salud global.
