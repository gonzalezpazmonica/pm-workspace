---
entity: {type: document, id: savia-domains-catalog}
title: Savia Domains — Catálogo abierto de dominios de conocimiento
doc_type: catalog
status: v0.1 (catalogacion)
confidentiality: N1
source: "Labs L23 — Savia Domains"
tags: [domains, catalog, verticals, cupulas, open-source, labs]
created_at: 2026-08-23
---

# Savia Domains — Catálogo abierto de dominios de conocimiento

> Catálogo de dominios (verticales) para los que Savia construirá **cúpulas de
> conocimiento propias, abiertas y publicadas en este repositorio** (pm-workspace).
> Base para trabajar verticales sin reinventar ni duplicar conocimiento.
> **Esta fase es CATALOGACIÓN**: la digestión de cada dominio (ingesta de
> contenido en su cúpula) vendrá después, cuando el catálogo esté definido.

## Estado del ciclo de vida (2026-08-27)

- **CATALOGADO**: 34 dominios / 11 categorías (validado por la operadora 2026-08-24).
- **CÚPULA CREADA** (2026-08-27): dome `SaviaDomains` (N1) registrado en
  `projects/savia-vaults/savia-vaults.domes.json` + cúpula por dominio en
  `vaults/SaviaDomains/<categoría>/<ID>/INDEX.md` (34).
  Regenerable: `python3 scripts/savia-domains-cupulas.py` (o `--check`).
- **Pendiente**: DIGERIDO (ingesta de contenido por dominio) — sigue el plan
  unificado (Batch 3 → SE-344).

## 1. Propósito

1. Definir la taxonomía de dominios en los que Savia opera o quiere operar.
2. Servir de **base neutra** para crear cúpulas de conocimiento por vertical
   (SaviaVaults), reutilizando skills, reglas y agentes transversales.
3. Evitar solapes: cada dominio tiene un ID único y una cúpula destino.
4. Mantener la apertura: el catálogo y las cúpulas son contenido **N1
   (público)** — conocimiento genérico de referencia, nunca datos de
   empresa/cliente/persona (N2-N4b van aparte).

## 2. Criterios de inclusión / exclusión

**Inclusión** — un dominio entra cuando es: un sector o área de conocimiento
con cuerpo propio, con demanda real de trabajo vertical, y no conflictivo.

**Exclusión (dominios sensibles o polémicos)** — fuera del catálogo:
química, farmacia, medicina y salud (biomédico clínico), armamento y defensa,
biotecnología dual, y cualquier dominio con riesgo de uso dual alto.
La decisión es de la operadora (Labs L23) y aplica a cúpulas públicas.

## 3. Taxonomía y catálogo (v0.1)

Estructura: **Categoría → Dominio (ID) → Temas objetivo** (para digestión
posterior, NO digeridos aún). La columna *Capacidad Savia* lista lo que ya
existe y sirve de cimiento.

| ID | Categoría | Dominio | Temas objetivo (digestión posterior) | Capacidad Savia existente |
|---|---|---|---|---|
| PUA | Sector público | Administración pública y gobierno digital | Procesos administrativos, digitalización de servicios públicos, interoperabilidad, datos abiertos | legal-compliance (RGPD) |
| CON | Sector público | Contratación pública | Licitaciones, LCSP, procedimientos de adjudicación, pliegos, recursos | legalize-es (parcial) |
| LEG | Legal y normativa | Derecho general | Civil, mercantil, laboral, administrativo, redacción de documentos | legal-compliance, professional-domain/legal |
| CMP | Legal y normativa | Compliance y regulación | RGPD, EU AI Act, normativa sectorial, matrices de riesgo | legal-compliance, regulatory-compliance |
| BNK | Finanzas | Banca | Productos bancarios, riesgos, normativa (BASEL), pagos, crédito | banking-architecture |
| INS | Finanzas | Seguros | Productos aseguradores, riesgos, siniestros, solvencia | — |
| FNC | Finanzas | Finanzas corporativas | Tesorería, DCF, valoración, inversión | professional-domain/finance |
| CTR | Finanzas | Controlling y gestión | KPIs, desviaciones, reporting mensual | professional-domain/controlling |
| SFT | Tecnología | Ingeniería de software | Arquitectura, lenguajes, DevOps, testing, calidad | 16 language packs, architect, courts |
| AID | Tecnología | IA y datos | ML, LLM, data engineering, RAG, MLOps | SE-027, tabular-intelligence, vaults, graph |
| CYB | Tecnología | Ciberseguridad | OWASP, red team, hardening, normativa | security-* agents, skills de seguridad |
| TLC | Tecnología | Telecomunicaciones | Redes, 5G, protocolos, infraestructura de red | — |
| ELC | Electrónica | Electrónica | Analógica/digital, componentes, diseño de PCB, sensores | — |
| SEM | Electrónica | Microelectrónica y semiconductores | Chips, fabricación, cadenas de suministro | — |
| RBT | Robótica | Robótica | Industrial, de servicio, autónoma, ROS, percepción | robotics-roadmap, mobile-dev |
| AUT | Robótica | Automatización industrial | PLC, SCADA, control, gemelo digital de planta | — |
| EDU | Educación | Educación | Pedagogía, currículos, FP, universidad | savia-school |
| EVA | Educación | E-learning y formación online | LMS, contenidos formativos, evaluación | savia-school |
| POW | Electricidad | Electricidad y sistemas eléctricos | Redes, generación, distribución, instalaciones | — |
| REN | Electricidad | Energías renovables | Solar, eólica, almacenamiento, balance de red | L10 (energy forecasting) |
| EFF | Electricidad | Eficiencia energética | Auditorías, gestión de demanda, certificación | — |
| INF | Infraestructuras | Infraestructuras y obra civil | Construcción, BIM, ciclo de vida de activos | infrastructure-agent (TI), digital twin |
| MOV | Infraestructuras | Transporte y movilidad | Logística urbana, transporte público, movilidad | — |
| IDS | Industria | Industria y fabricación | Procesos, calidad, lean, gemelo digital | — |
| LOG | Industria | Logística y cadena de suministro | Warehouse, inventario, transporte, trazabilidad | — |
| RTL | Comercio | Retail y comercio | E-commerce, retail, merchandising | professional-domain/sales |
| SLS | Comercio | Ventas B2B | Pipeline, MEDDIC, propuestas | professional-domain/sales |
| MKT | Comercio | Marketing y comunicación | Campañas, marca, contenidos, analítica | — |
| HRS | Personas | Recursos humanos y trabajo | Nóminas, convenios, onboarding, conflictos laborales | professional-domain/labour |
| AGR | Sector productivo | Agroalimentación | Agricultura, alimentación, trazabilidad | — |
| TUR | Sector productivo | Turismo y hostelería | Hotelería, destinos, estacionalidad | — |
| CUL | Sector productivo | Cultura y patrimonio | Patrimonio, museos, industrias culturales | — |
| MDS | Sector productivo | Medios y comunicación | Periodismo, contenidos, audiencias | — |
| SUS | Transversal | Sostenibilidad y medio ambiente | ESG, economía circular, huella de carbono | — |

**Programas verticales:** un programa vertical integra varios dominios del
catálogo para un fin concreto.

- **Savia Farming** (Labs L24, 2026-08-23): rediseña el sector primario con
  robótica, electrónica, informática, mecánica e IA, e integra los dominios
  **AGR** (Agroalimentación), **RBT** (Robótica), **ELC** (Electrónica),
  **POW/REN/EFF** (Electricidad y energía), **AID** (IA y datos) e **INF**
  (Infraestructuras) — en clave de soberanía distribuida (datos agronómicos
  gobernados en infraestructura propia, CRIT-001).
- **Savia Humanity** (Labs L25, 2026-08-23): estudia el envejecimiento y la
  transición demográfica, el cuidado de personas mayores y dependientes, y la
  producción de alimentos — **enlazada con Savia Farming**. Integra **HRS**
  (Recursos humanos y trabajo: cuidados), **RBT** (robótica asistencial),
  **AID** (IA y datos) e **INF** (infraestructuras de teleasistencia). Frontera
  ética (regla L23): el cuidado social y la autonomía sí; el contenido
  biomédico clínico, no.

## 4. Ciclo de vida de un dominio

```
PROPUESTO ──(validacion operadora)──► CATALOGADO ──► CUPULA CREADA ──► DIGERIDO
  (candidato)                          (en este doc)  (SaviaVaults, N1)  (contenido ingerido)
```

- **Catalogado** = tiene fila en este catálogo con ID y temas objetivo.
- **Cúpula creada** = domo abierto en SaviaVaults (N1) con su DOMAIN.md.
- **Digerido** = contenido de referencia ingerido (skills, normas, patrones) —
  fase posterior, alineada con la digestión de SE-342 y el puente de dominio
  de `knowledge-graph-domain-bridge.py`.

## 5. Apertura y soberanía (CRIT-001)

- El catálogo y las cúpulas de dominio son **contenido N1 publicado en este
  repositorio**: conocimiento genérico, reusable y abierto.
- Los datos de empresa/cliente/persona (N2-N4b) jamas se mezclan con el
  contenido de dominio: las cúpulas de Savia Domains son conocimiento, no datos.
- CRIT-001: todo el ciclo corre en infraestructura propia; datos N3+ jamas
  salen a proveedor cloud.

## 6. Dirección estratégica — capa de datos por dominio, soberana

Existe un modelo comercial de referencia de "capa de datos para agentes": un
servicio en nube que pre-procesa el conocimiento público, lo organiza por
**directorios de dominio** (cada vertical con sus fuentes y su esquema tipado),
lo sirve como **hechos estructurados** (no prosa) con proveniencia, períodos de
validez y cita de fuente, y expone **un único endpoint MCP** que cualquier
agente del protocolo puede consultar. Se paga por consulta (créditos) y todo se
hospeda en el perímetro del proveedor.

**Savia Domains + SaviaVaults es la alternativa soberana, local y libre** de ese
modelo:

| Capacidad del modelo comercial | Equivalente soberano en Savia |
|---|---|
| Directorios de dominio | Este catálogo → cúpulas por dominio (SaviaVaults) |
| Hechos tipados con lineage y validades | `knowledge-graph.py` (entidades+relaciones tipadas), catálogo L17 |
| Ingesta de fuentes públicas | Pipeline de digestión (pdf/word/excel/reuniones) |
| Búsqueda / consulta | Búsqueda híbrida BM25+vector (L22) sobre cúpulas |
| Endpoint único MCP para agentes | MCP server del vault (SaviaVaults) |
| Verificación / proveniencia | Cita de fuente + hash de contenido |

Diferenciales: **soberano** (CRIT-001: datos N3+ jamás salen, ni temporal ni
anonimizados a mano), **local** (Ollama/LocalAI, SQLite, git en el workspace),
**libre y abierto** (sin API key, sin créditos, sin metering; cúpulas N1 en este
repo), y **exclusiones por diseño** (los dominios sensibles del §2 quedan fuera
del catálogo). La brecha real no es tecnológica sino de **contratos de consulta
tipada por dominio** y **corpus estructurado** — ambos se resuelven en la fase de
digestión.

## 7. Próximos pasos

1. **Validar este catálogo** con la operadora (Labs L23) — ajustar dominios,
   IDs o exclusiones antes de abrir cúpulas.
2. Crear cúpulas N1 por dominio (una por prioridad de vertical).
3. Digerir dominios priorizados (skill + DOMAIN.md + corpus de referencia).
4. Definir **contrato de consulta tipada por dominio** (operaciones + esquema)
   sobre el MCP del vault, a imagen del modelo de referencia (§6).
5. Alimentar el grafo de conocimiento (entity types por dominio).

---

## Referencias

- Labs: línea **L23 — Savia Domains** (cúpula SaviaLabs).
- Cúpulas: SaviaVaults (SE-280..SE-331); contenido N1 según
  `docs/confidentiality-levels.md`.
- Cimientos: `professional-domain/` (legal, finance, labour, sales,
  controlling), `legal-compliance` (legalize-es), `savia-school`,
  `banking-architecture`, L10 (energía), `robotics-roadmap`.
- Deuda/evolución: `docs/savia-future-analysis-2026-08-23.md`, SE-342.
